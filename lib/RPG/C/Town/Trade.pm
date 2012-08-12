package RPG::C::Town::Trade;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub default : Path {
	my ($self, $c) = @_;

	$c->forward('trade');
}

sub trade : Local {
    my ($self, $c) = @_;
    
    my $town = $c->stash->{party_location}->town;
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/trade/main.html',
				params   => {
				    party => $c->stash->{party},
				    town => $town,
					selected => $c->req->param('selected') || '',
					error => $c->flash->{error} || '',
					message => $c->flash->{message} || '',
				},
			}
		]
	);    
}

sub buy : Local {
    my ($self, $c) = @_;    
    
    my @trades = $c->model('DBIC::Trade')->search(
        {
            status => 'Offered',
            town_id => $c->stash->{party_location}->town->id,
            party_id => {'!=', $c->stash->{party}->id},
            offered_to => [undef, $c->stash->{party}->id],
        }
    );    
    
    $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/trade/buy.html',
				params   => {
				    trades => \@trades,
				    town => $c->stash->{party_location}->town, 
				    party => $c->stash->{party},
				},
			}
		]
	);     
}

sub sell : Local {
    my ($self, $c) = @_;    
   
    my @trades = $c->model('DBIC::Trade')->search(
        {
            status => ['Offered', 'Accepted'],
            town_id => $c->stash->{party_location}->town->id,
            party_id => $c->stash->{party}->id,
        }
    );    
    
    $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/trade/sell.html',
				params   => {
				    trades => \@trades,
				    town => $c->stash->{party_location}->town, 
				},
			}
		]
	);    
}

sub equipment : Local {
    my ($self, $c) = @_;    
    
    my @categories = $c->model('DBIC::Item_Category')->search( { hidden => 0 }, { order_by => 'item_category', }, );
    
    my $selected_category;
    
    if ($c->req->param('category_filter')) {
        if ($c->req->param('category_filter') ne 'clear') {            
            ($selected_category) = grep { $_->id == $c->req->param('category_filter') } @categories;
        }
    }
    else {
        $selected_category = $categories[0] unless $selected_category;
    }
    
    my $selected_character;
    ($selected_character) = grep { $_->id == $c->req->param('character_filter') } $c->stash->{party}->characters_in_party
        if $c->req->param('character_filter');
    
	my @equipment = $c->model('DBIC::Items')->search(
    	{ 
        	'belongs_to_character.character_id' =>
        	   $selected_character ?
        	       $selected_character->id :
        	       [map { $_->id } $c->stash->{party}->characters_in_party], 
        	       
        	$selected_category ? ('item_type.item_category_id' => $selected_category->id) : (),
        	
        },
        {
        	join => 'belongs_to_character',
            prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
            order_by => 'item_category',
        },
    );       
    
    $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/trade/equipment.html',
				params   => {
				    characters => [$c->stash->{party}->characters_in_party],
				    categories => \@categories,
				    selected_category => $selected_category,
				    selected_character => $selected_character,
				    equipment => \@equipment,				     
				},
			}
		]
	);       
}

sub create : Local {
    my ($self, $c) = @_;
    
    my $item = $c->model('DBIC::Items')->find(
        {
            item_id => $c->req->param('trade_item_id'),
        },         
        {
            # Lock the item row - prevents multiple trade rows getting created
            for => 'update', 
        },
    );
    
    croak "Item not found" unless $item;
    
    if (! grep { $_->id == $item->character_id } $c->stash->{party}->characters_in_party) {
        croak "Attempt to sell an item not in party";   
    }
    
    # Check sell price is reasonable
    my $base_price = $item->sell_price;
    my $sell_price = $c->req->param('price');
    
    my $percent_diff = abs RPG::Maths->precentage_difference($base_price, $sell_price);
    
    if ($sell_price <= 0 || $percent_diff >= $c->config->{trade_max_percentage_difference_in_base_price}) {
        push @{$c->stash->{error}}, "Your sell price is too high or too low!";
        $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell']] ); 
        return;
    }
    
    my $offer_to;
    if ($c->req->param('offer_to')) {
        my $offer_party = $c->model('DBIC::Party')->find(
            {
                name => $c->req->param('offer_to'),
                defunct => undef,
            }
        );
        
        if (! $offer_party) {
            push @{$c->stash->{error}}, "The party " . $c->req->param('offer_to') . " does not exist";
            $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell']] ); 
            return;              
        }
        
        if ($offer_party->id == $c->stash->{party}->id) {
            push @{$c->stash->{error}}, "You can't offer to your own party!";
            $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell']] ); 
            return;            
        }
        
        if ($c->stash->{party}->is_suspected_of_coop_with($offer_party)) {
            push @{$c->stash->{error}}, "You can't trade with this party, as you have IP addresses in common";
            $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell']] ); 
            return;
        }
        
        $offer_to = $offer_party->id;
        
    }
    
    $item->belongs_to_character->remove_item_from_grid($item);
    $item->character_id(undef);    
    $item->equip_place_id(undef);
    $item->update;
    
    # Make sure there's no existing open trade for this item
    my $existing_trade = $c->model('DBIC::Trade')->find(
        {
            item_id => $item->id,
            status => 'Offered',
        },
    );
    
    croak "Already an open trade for item " . $item->id if $existing_trade;
    
    my $trade = $c->model('DBIC::Trade')->create(
        {
            item_id => $item->id,
            party_id => $c->stash->{party}->id,
            town_id => $c->stash->{party_location}->town->id,
            amount => $sell_price,
            status => 'Offered',
            item_base_value => $base_price,
            item_type => $item->display_name,
            offered_to => $offer_to,        
        }
    );
    
    $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell']] );            
}

sub cancel : Local {
    my ($self, $c) = @_;

    my $trade = $c->model('DBIC::Trade')->find($c->req->param('trade_id'));
    
    if (! $trade || $trade->party_id != $c->stash->{party}->id || $trade->town_id != $c->stash->{party_location}->town->id) {
        croak "Invalid trade";   
    }
    
    if ($trade->status ne 'Offered') {
        croak "Can only cancel an offered trade";   
    }
    
    my $item = $trade->item;
    my $character = $c->stash->{party}->give_item_to_character($item);    
    
    $trade->status('Cancelled');
    $trade->update;
    
    $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell']] );
}

sub purchase : Local {
    my ($self, $c) = @_;

    my $trade = $c->model('DBIC::Trade')->find($c->req->param('trade_id'));
    
    if (! $trade || $trade->status ne 'Offered' || $trade->town_id != $c->stash->{party_location}->town->id || $trade->party_id == $c->stash->{party}->id) {
        croak "Invalid trade";   
    }
    
    if ($trade->offered_to && $trade->offered_to != $c->stash->{party}->id) {
        croak "Item not offered to this party";
    }
    
    my $selling_party = $trade->party;
    
    if ($trade->amount > $c->stash->{party}->gold) {        
        push @{$c->stash->{error}}, "You don't have enough gold to buy that item";
    }
    elsif ($c->stash->{party}->is_suspected_of_coop_with($selling_party)) {
        push @{$c->stash->{error}}, "You can't trade with this party, as you have IP addresses in common";
    }
    else {
        $c->stash->{party}->decrease_gold($trade->amount);
        $c->stash->{party}->update;
        
        my $item = $trade->item;
        my $character = $c->stash->{party}->give_item_to_character($item);    
        
        $trade->status('Accepted');
        $trade->purchased_by($c->stash->{party}->id);
        $trade->update;
        
        $selling_party->add_to_messages(
            {
                day_id => $c->stash->{today}->id,
                alert_party => 1,
                message => "The " . $item->display_name . " you offered in " . $c->stash->{party_location}->town->town_name . " has been purchased by "
                    . $c->stash->{party}->name . ". Return to the town to pick up the gold",
            }
        );
        
        push @{$c->stash->{error}}, "Item purchased, and added to " . $character->name . "'s inventory";
    }


    $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=buy'], 'party_status'] );

}

sub collect : Local {
    my ($self, $c) = @_;

    my $trade = $c->model('DBIC::Trade')->find($c->req->param('trade_id'));
    
    if (! $trade || $trade->status ne 'Accepted' || $trade->town_id != $c->stash->{party_location}->town->id || $trade->party_id != $c->stash->{party}->id) {
        croak "Invalid trade";   
    }
    
    $c->stash->{party}->increase_gold($trade->amount);
    $c->stash->{party}->update;
    
    $trade->status('Complete');
    $trade->update;
    
    push @{$c->stash->{error}}, "Gold collected";
    
    $c->forward( '/panel/refresh', [[screen => 'town/trade?selected=sell'], 'party_status'] );
}

1;
