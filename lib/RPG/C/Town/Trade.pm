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
    
    my $item = $c->model('DBIC::Items')->find($c->req->param('trade_item_id'));
    
    croak "Item not found" unless $item;
    
    if (! grep { $_->id == $item->character_id } $c->stash->{party}->characters_in_party) {
        croak "Attempt to sell an item not in party";   
    }
    
    # TODO: check sell price is reasonable?
    
    $item->character_id(undef);
    $item->equip_place_id(undef);
    $item->update;
    
    my $trade = $c->model('DBIC::Trade')->create(
        {
            item_id => $item->id,
            party_id => $c->stash->{party}->id,
            town_id => $c->stash->{party_location}->town->id,
            amount => $c->req->param('price'),
            status => 'Offered',
        }
    );
    
    $c->response->redirect( $c->config->{url_root} . '/town/trade?selected=sell' );
            
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
    my $character = $c->stash->{party}->get_least_encumbered_character;        		
        
    $item->add_to_characters_inventory($character);    
    
    $trade->status('Cancelled');
    $trade->update;
    
    $c->response->redirect( $c->config->{url_root} . '/town/trade?selected=sell' );
}

sub purchase : Local {
    my ($self, $c) = @_;

    my $trade = $c->model('DBIC::Trade')->find($c->req->param('trade_id'));
    
    if (! $trade || $trade->status ne 'Offered' || $trade->town_id != $c->stash->{party_location}->town->id || $trade->party_id == $c->stash->{party}->id) {
        croak "Invalid trade";   
    }
    
    if ($trade->amount > $c->stash->{party}->gold) {        
        $c->flash->{error} = "You don't have enough gold to buy that item";
    }
    else {
        $c->stash->{party}->decrease_gold($trade->amount);
        $c->stash->{party}->update;
        
        my $item = $trade->item;
        my $character = $c->stash->{party}->get_least_encumbered_character;        		
            
        $item->add_to_characters_inventory($character);    
        
        $trade->status('Accepted');
        $trade->update;
        
        $trade->party->add_to_messages(
            {
                day_id => $c->stash->{today}->id,
                alert_party => 1,
                message => "The " . $item->display_name . " you offered in " . $c->stash->{party_location}->town->town_name . " has been purchased by "
                    . $c->stash->{party}->name . ". Return to the town to pick up the gold",
            }
        );
        
        $c->flash->{message} = "Item purchased, and added to " . $character->name . "'s inventory";
    }

    $c->response->redirect( $c->config->{url_root} . '/town/trade?selected=buy' );

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
    
    $c->flash->{message} = "Gold collected";
    
    $c->response->redirect( $c->config->{url_root} . '/town/trade?selected=sell' );
}

1;
