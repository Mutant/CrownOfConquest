package RPG::C::Shop;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;
use Set::Object qw(set);
use Try::Tiny;

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
	
	my @tabs = $shop->tabs;

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
					tabs          => \@tabs,
				}
			}
		]
	);
}

sub character_inventory : Local {
    my ( $self, $c ) = @_;
    	
    $c->visit('/character/equipment_tab', [1]);
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
	
	if (! $item) {
		push @{ $c->stash->{error} }, "The shop no longer has this item. Another party may have bought it!";
		$c->forward( '/panel/refresh' );
		return;
	}	
	
	croak "Can't buy quantity item" if $item->is_quantity;

	my $party = $c->stash->{party};

    my $shop = $item->in_shop;
	my $town = $shop->in_town;

	if ( $town->id != 0 && $town->id != $party->location->town->id ) {
		croak "Attempting to buy an item in another town";
	}
	
    my $cost = $item->sell_price( $item->in_shop, 0 );

	if ( $party->gold < $cost ) {
		push @{ $c->stash->{error} }, "Your party doesn't have enough gold to buy this item";
		
        $c->stash->{panel_callbacks} = [
        	{
            	name => 'purchaseFailed',
            	data => {
            	    item_id => $item->id,
            	},
        	}
        ];	
			
		
		$c->forward( '/panel/refresh' );
		return;
	}
	
	# The town takes its cut
	if ($cost > 1) {
	   $town->take_sales_tax($cost);
	   $town->update;
	}

	my ($character) = grep { $_->id == $c->req->param('character_id') } $party->characters_in_party;
	
	if ($c->req->param('equip_place')) {
	    $item->character_id($character->id);
	    $item->update;        
	    my $ret = $c->forward('/character/equip_item_impl', [$item]);
	    $item->add_to_characters_inventory($character);
	    
	    $c->stash->{panel_callbacks} = [
        	{
            	name => 'equipItem',
            	data => $ret,
        	}
        ];
	}
	else {
	   $item->add_to_characters_inventory($character, { x => $c->req->param('grid_x'), y => $c->req->param('grid_y')}, 0);
	}

	$party->gold( $party->gold - $cost );
	$party->update;
	
	my $item_sector = $shop->find_related('item_sectors',
	   {
	       item_id => $item->id,
	       start_sector => 1,
	   }
	);
	
	if ($item_sector->quantity > 1) {        
        # Find next item id
        my $next_item = $shop->search_related('items_in_shop',
            {
                item_type_id => $item->item_type_id,
            }
        )->first;
        
	    push @{$c->stash->{panel_callbacks}}, {
        	name => 'updateStackItemData',
        	data => {
        	    original_item_id => $item->id,
        	    new_item_id => $next_item->id,
        	    new_quantity => $item_sector->quantity-1,
        	    character_id => $character->id,
        	},
    	};
    	
        $item_sector->quantity($item_sector->quantity-1);
        $item_sector->item_id($next_item->id);
        $item_sector->update;
	}
	else {	
	   $shop->remove_item_from_grid($item);
	}

    $c->forward( '/panel/refresh', ['party_status'] );
}

sub buy_quantity_item : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

    my $item = $c->model('DBIC::Items')->find(
 		{
			item_id => $c->req->param('item_id'),
 		},
		{
			prefetch => 'item_type',
		}
 	);
 	
 	croak "Not quantity item" unless $item->is_quantity;
 	
    croak "No quantity supplied" if ! $c->req->param('quantity');
    
    croak "Invalid quantity" unless $c->req->param('quantity') =~ /^\d+$/;
    
    my $shop = $item->in_shop;
	my $town = $shop->in_town;    
 
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
	my $stacked_on_item = $new_item->add_to_characters_inventory($character, { x => $c->req->param('grid_x'), y => $c->req->param('grid_y')});

	$party->gold( $party->gold - $cost );
	$party->update;
	
	# Deduct amount from shop's item
	my $new_shop_quantity = $item->variable( 'Quantity' ) - $c->req->param('quantity');
	$item->variable( 'Quantity', $new_shop_quantity );
	if ($new_shop_quantity <= 0) {
	    $shop->remove_item_from_grid($item);
	    $item->delete;
	}
		
    $c->stash->{panel_callbacks} = [
    	{
        	name => 'quantityPurchase',
        	data => {
        	    shop_item => {
        	       item_id => $item->id,
        	       quantity => $new_shop_quantity,
        	    },
                item_stacked => defined $new_item->character_id ? 0 : 1,
                inv_item => $new_item->id,
                stacked_on_item => $stacked_on_item ? $stacked_on_item->id : undef,
        	},
    	}
    ];	
	

    $c->forward( '/panel/refresh', ['party_status'] );       
}
 
sub sell_item : Local {
	my ( $self, $c ) = @_;

	my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), }, { prefetch => { 'item_type' => 'category' }, }, );
	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id'), } );
	
	croak "Invalid item" if ! $item;
	croak "Invalid shop" if ! $shop;
	
	my $character = $item->belongs_to_character;

	# Make sure this item belongs to a character in the party
	my @characters = $c->stash->{party}->characters_in_party;
	if ( scalar( grep { $_->id == $item->character_id } @characters ) == 0 ) {
		croak "Selling item from invalid character";
	}

	# Make sure the shop they're in is in the town they're in
	if ( $shop->town_id != $c->stash->{party}->location->town->id ) {
		$c->res->body( to_json( { error => "Attempting to sell an item in another town" } ) );

		# TODO: this does allow them to sell items from a different shop, which may or may not be OK
		return;
	}
	
	my $sell_price = $item->sell_price($shop);
	
	my $removed_quantity_item;
	my $existing_shop_quantity_item;

	if ( $item->variable('Quantity') ) {
	    my $quantity_for_shop = 0;
	    
	    my $quantity_to_sell = $c->req->param('quantity');
	    $quantity_to_sell = 0 if $quantity_to_sell !~ /^\d+/; 
	    
	    if (defined $quantity_to_sell && $quantity_to_sell != $item->variable('Quantity')) {
            if ($quantity_to_sell > $item->variable('Quantity')) {
                $c->res->body( to_json( { error => "You can't sell more than you have!" } ) );
                return;
            }
            
            if ($quantity_to_sell <= 0) {
                $c->res->body( to_json( { error => "Invalid quantity" } ) );
                return;
            }

            $sell_price = $item->individual_sell_price($shop) * $quantity_to_sell;            
            $item->variable('Quantity', $item->variable('Quantity') - $quantity_to_sell);
            $quantity_for_shop = $quantity_to_sell;
	    }
	    else {
    		# Selling the whole thing, just delete it.
    		$quantity_for_shop = $item->variable('Quantity');
    		$character->remove_item_from_grid($item);
    		$removed_quantity_item = $item->id;
            $item->delete;
	    }
	    
	    # Add it to the shop
	    if (! $item->item_type->category->delete_when_sold_to_shop && $quantity_for_shop) {
            my $shop_item = $c->model('DBIC::Items')->find_or_new(
                {
                    shop_id => $shop->id,
                    item_type_id => $item->item_type_id,
                },
            );
            
            my $new_quantity;
            if ($shop_item->in_storage) {
                $new_quantity = $shop_item->variable('Quantity') + $quantity_for_shop;                
            }
            else {
                $shop_item->insert;
                $new_quantity = $quantity_for_shop;
                
                try {
                    $shop->add_item_to_grid($shop_item);
                }
                catch {
                    $c->log->debug("Error when adding item to shop grid: $_");
                };
            }
                     
            $shop_item->variable('Quantity', $new_quantity);
            $shop_item->update;            
            
            $existing_shop_quantity_item = $shop_item->id;
	    } 
	    
	}

	else {
    	$item->character_id(undef);
    	$item->equip_place_id(undef);
    	$character->remove_item_from_grid($item);

		# If it's not a quantity item, give it back to the shop, except for item categories with "delete_when_sold_to_shop"
		if ( ! $item->item_type->category->delete_when_sold_to_shop ) {
			if ($item->has_variable('Durability')) {
				# Reset the item's durability
				$item->variable('Durability', $item->variable_max('Durability'));
			}			
			
			$item->shop_id( $shop->id );
			$item->update;
			try {
                $shop->add_item_to_grid($item);
            }
            catch {
                $c->log->debug("Error when adding item to shop grid: $_");
            };
		}
		else {
			$item->delete;
		}
	}
	
	$c->stash->{party}->gold( $c->stash->{party}->gold + $sell_price );
	$c->stash->{party}->update;

	my $messages = $c->forward( '/quest/check_action', [ 'sell_item', $item ] );

    $c->stash->{panel_callbacks} = [
    	{
        	name => 'sell',
        	data => {
        	    messages => $messages,
        	    remove_item => $removed_quantity_item,
        	    existing_shop_quantity_item => $existing_shop_quantity_item,
        	},
    	}
    ];


    $c->forward( '/panel/refresh', ['party_status'] );    
}

sub item_tab : Local {
	my ( $self, $c ) = @_;
    
	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;
	
	croak "Shop closed" if $shop->status eq 'Closed' || $shop->status eq 'Opening';
	
	my $items_in_grid = $shop->items_in_grid($c->req->param('tab'));	

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/item_tab.html',
				params   => {
					items_in_grid => $items_in_grid,
					tab => $c->req->param('tab'),
				}
			}
		]
	);
}

1;
