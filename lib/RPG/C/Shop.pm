package RPG::C::Shop;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;
use Set::Object qw(set);

sub purchase : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;

	if ( $shop->status eq 'Closed' || $shop->status eq 'Opening' ) {
		$c->detach(
			'RPG::V::TT',
			[
				{
					template => 'shop/not_open.html',
					params   => {
						shop          => $shop,
						shops_in_town => \@shops_in_town,
						gold          => $party->gold,
					}
				}
			]
		);
	}

	my @characters = $party->characters;
	
	my $items_in_grid = $shop->items_in_grid;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/purchase2.html',
				params   => {
					shop          => $shop,
					characters    => \@characters,
					shops_in_town => \@shops_in_town,
					items_in_grid => $items_in_grid,
					town          => $party->location->town,
				}
			}
		]
	);
}

sub character_inventory : Local {
    my ( $self, $c ) = @_;
    	
    $c->visit('/character/equipment_tab');
}

sub standard_tab : Local {
    my ( $self, $c ) = @_;
    
	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;    
    	
	my %items_in_grid = $shop->items_in_grid;

	# Get a sorted list of categories
	my @categories = $c->model('DBIC::Item_Category')->search( {}, { order_by => 'item_category', }, );
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/standard_items.html',
				params   => {
					shop  => $shop,
					items_in_grid => \%items_in_grid,
				}
			}
		]
	);
}

sub enchanted_tab : Local {
	my ( $self, $c ) = @_;

    $c->forward('item_tab', [1]);

}

sub item_tab : Private {
    my ( $self, $c, $enchanted ) = @_;
    
	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;
	
	my @items = $enchanted ? $shop->enchanted_items_in_shop : $shop->grouped_items_in_shop;

	# Put everything into a hash by category
	my %items;
	foreach my $item (@items) {
	    my $sell_type = 'item';
	    $sell_type = 'quantity' if $item->has_variable('Quantity');
	    $sell_type = 'enchanted' if $enchanted;
	    
		push @{ $items{ $item->item_type->category->item_category }{$sell_type} }, $item;
	}

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/item_list.html',
				params   => {
					shop  => $shop,
					items => \%items,
				}
			}
		]
	);    
}

sub sell : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;

	my @characters = $party->characters;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/sell.html',
				params   => {
					shop          => $shop,
					characters    => \@characters,
					shops_in_town => \@shops_in_town,
					gold          => $party->gold,
					town          => $party->location->town,
					current_tab   => $c->session->{sell_active_tab} || '',
				}
			}
		]
	);
}

sub character_sell_tab : Local {
	my ( $self, $c ) = @_;

	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			garrison_id  => undef,
		}
	);

	croak "Invalid character" unless $character->party_id == $c->stash->{party}->id;

	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id') } );

	if ( $shop->town_id != $c->stash->{party}->location->town->id ) {
		croak "Invalid shop";
	}

	$c->session->{sell_active_tab} = $character->id;

	my @items = $c->model('DBIC::Items')->search(
		{ character_id => $c->req->param('character_id'), },
		{
			prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
			order_by => 'item_category',
		},
	);

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/character_sell_tab.html',
				params   => {
					items     => \@items,
					shop      => $shop,
					character => $character,
				}
			}
		]
	);
}

sub buy_item : Local {
	my ( $self, $c ) = @_;
	
    my $item = $c->model('DBIC::Items')->find(
		{
			item_id => $c->req->param('item_id'),
		},
		{
			prefetch => 'item_type',
		}
	);

	my $party = $c->stash->{party};

    my $shop = $item->in_shop;
	my $town = $shop->in_town;

	if ( $town->id != 0 && $town->id != $party->location->town->id ) {
		croak "Attempting to buy an item in another town";
	}
	my $count = 0;
	my $cost = 0;
	my $enchanted = 0;

	if (! $item) {
		push @{ $c->stash->{error} }, "The shop no longer has this item. Another party may have bought it!";
		$c->forward( '/panel/refresh' );
		return;
	}
	
	$cost = $item->sell_price( $item->in_shop, 0 );	

	if ( $party->gold < $cost ) {
		push @{ $c->stash->{error} }, "Your party doesn't have enough gold to buy this item";
		$c->forward( '/panel/refresh' );
		return;
	}
	
	# The town takes its cut
	if ($cost > 1) {
	   $town->take_sales_tax($cost);
	   $town->update;
	}

	my ($character) = grep { $_->id == $c->req->param('character_id') } $party->characters_in_party;

	$item->add_to_characters_inventory($character, { x => $c->req->param('grid_x'), y => $c->req->param('grid_y')});

	$party->gold( $party->gold - $cost );
	$party->update;
	
	$shop->remove_item_from_grid($item);

    $c->forward( '/panel/refresh', ['party_status'] );
}

# TODO: fair bit of duplication between this and buy_item
sub buy_quantity_item : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	# Make sure the shop they're in checks out
	my $shop = $c->model('DBIC::Shop')->find(
		{
			shop_id => $c->req->param('shop_id'),
		},
	);

	croak  "Invalid shop" unless $shop;

	my $item = $c->model('DBIC::Items')->find( 
	   { 
	       item_id => $c->req->param('item_id'),
	       shop_id => $c->req->param('shop_id'), 
	   }
	);
	
	croak "Invalid item" unless $item;

	# Make sure the shop they're in is in the town they're in
	if ( $shop->town_id != 0 && $shop->town_id != $party->location->town->id ) {
		croak "Attempting to buy an item in another town";

		# TODO: this does allow them to buy items from a different shop, which may or may not be OK
		return;
	}

    my $indvidual_cost = $item->item_type->modified_cost($shop);
	my $cost = $indvidual_cost * $c->req->param('quantity');

	if ( $party->gold < $cost ) {
		push @{ $c->stash->{error} }, "Your party doesn't have enough gold to buy this item";
		$c->forward( '/panel/refresh' );
		return;
	}
	
	if ( $item->variable('Quantity') < $c->req->param('quantity') ) {
		push @{ $c->stash->{error} }, "The shop does not have enough of this item";
		$c->forward( '/panel/refresh' );
		return;
	}

	# The town takes its cut, so long as the indvidual items are worth at least 1 gold
	if ($indvidual_cost > 1) {
        my $town = $shop->in_town;
        $town->take_sales_tax($cost);
        $town->update;
	}	

	# Create a new item for the party
	my $new_item = $c->model('DBIC::Items')->create( { item_type_id => $item->item_type_id, } );

    my ($character) = grep { $_->id == $c->req->param('character_id') } $party->characters_in_party;

	$new_item->variable( 'Quantity', $c->req->param('quantity') );
	$new_item->add_to_characters_inventory($character);

	$party->gold( $party->gold - $cost );
	$party->update;
	
	# Deduct amount from shop's item
	my $new_shop_quantity = $item->variable( 'Quantity' ) - $c->req->param('quantity');
	$item->variable( 'Quantity', $new_shop_quantity );
	if ($new_shop_quantity <= 0) {
	    $item->delete;
	}
	
    $c->stash->{panel_callbacks} = [
    	{
        	name => 'quantityPurchase',
        	data => {
        	    item_id => $item->id,
        	    quantity => $new_shop_quantity,
        	},
    	}
    ];	
	 
   
    $c->forward( '/panel/refresh', ['party_status'] );

}

sub sell_item : Local {
	my ( $self, $c ) = @_;

	my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), }, { prefetch => { 'item_type' => 'category' }, }, );
	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id'), } );
	
	my $original_char = $item->character_id;

	if ( !$c->forward( 'sell_single_item', [ $item, $shop ] ) ) {
		return;
	}

	my $messages = $c->forward( '/quest/check_action', [ 'sell_item', $item ] );

    $c->stash->{panel_callbacks} = [
    	{
        	name => 'sell',
        	data => {
        	    char_id => $original_char,
        	    messages => $messages,
        	},
    	}
    ];	

    $c->forward( '/panel/refresh', ['party_status'] );    
}

sub sell_multi_item : Local {
	my ( $self, $c ) = @_;

	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id'), } );
	my @item_ids = $c->req->param('item_id');

	my @items = $c->model('DBIC::Items')->search(
		{
			item_id => \@item_ids,
		},
		{ prefetch => { 'item_type' => 'category' }, },
	);

    my $original_char;
	my @messages;
	foreach my $item (@items) {
	    $original_char = $item->character_id;
	    
		if ( !$c->forward( 'sell_single_item', [ $item, $shop ] ) ) {
			return;
		}

		my $messages = $c->forward( '/quest/check_action', [ 'sell_item', $item ] );
		@messages = ( @messages, @$messages );
	}
	
    $c->stash->{panel_callbacks} = [
    	{
        	name => 'sell',
        	data => {
        	    char_id => $original_char,
        	    messages => \@messages,
        	},
    	}
    ];	

    $c->forward( '/panel/refresh', ['party_status'] );
}

sub sell_single_item : Private {
	my ( $self, $c, $item, $shop ) = @_;

	# Make sure this item belongs to a character in the party
	my @characters = $c->stash->{party}->characters;
	if ( scalar( grep { $_->id eq $item->character_id } @characters ) == 0 ) {
		$c->log->warn( "Attempted to sell item "
				. $item->id
				. " by party "
				. $c->stash->{party}->id
				. ", but item does not belong to this party (item is owned by character: "
				. $item->character_id
				. ")" );
		return;
	}

	# Make sure the shop they're in is in the town they're in
	if ( $shop->town_id != $c->stash->{party}->location->town->id ) {
		$c->res->body( to_json( { error => "Attempting to sell an item in another town" } ) );

		# TODO: this does allow them to sell items from a different shop, which may or may not be OK
		return;
	}
	
	my $sell_price = $item->sell_price($shop);

	if ( $item->variable('Quantity') ) {
	    my $quantity_for_shop = 0;
	    
	    if ($c->req->param('quantity') && $c->req->param('quantity') != $item->variable('Quantity')) {
            if ($c->req->param('quantity') > $item->variable('Quantity')) {
                $c->res->body( to_json( { error => "You can't sell more than you have!" } ) );
                return;
            }
            
            if ($c->req->param('quantity') < 0) {
                $c->res->body( to_json( { error => "Invalid quantity" } ) );
                return;
            }

            $sell_price = $item->individual_sell_price($shop) * $c->req->param('quantity');            
            $item->variable('Quantity', $item->variable('Quantity') - $c->req->param('quantity'));
            $quantity_for_shop = $c->req->param('quantity');
	    }
	    else {
    		# Selling the whole thing, just delete it.
    		$quantity_for_shop = $item->variable('Quantity');
            $item->delete;
	    }
	    
	    # Add it to the shop
	    if ($quantity_for_shop) {
            my $shop_item = $c->model('DBIC::Items')->find_or_create(
                {
                    shop_id => $shop->id,
                    item_type_id => $item->item_type_id,
                },
            );
            
            $shop_item->variable('Quantity', $shop_item->variable('Quantity') + $quantity_for_shop);
            $shop_item->update;
	    } 
	    
	}

	else {
    	$item->character_id(undef);
    	$item->equip_place_id(undef);

		# If it's not a quantity item, give it back to the shop, except for item categories with "delete_when_sold_to_shop"
		if ( ! $item->item_type->category->delete_when_sold_to_shop ) {
			if ($item->has_variable('Durability')) {
				# Reset the item's durability
				$item->variable('Durability', $item->variable_max('Durability'));
			}			
			
			$item->shop_id( $shop->id );
			$item->update;
		}
		else {
			$item->delete;
		}
	}
	
	$c->stash->{party}->gold( $c->stash->{party}->gold + $sell_price );
	$c->stash->{party}->update;

	return 1;
}

1;
