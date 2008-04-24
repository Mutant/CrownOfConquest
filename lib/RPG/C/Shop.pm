package RPG::C::Shop;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

sub purchase : Local {
    my ($self, $c) = @_;
    
    my $party = $c->stash->{party};
    
    my @shops_in_town = $party->location->town->shops;
    
    my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;

    my @characters = $party->characters;
    
    my @items = $shop->grouped_items_in_shop;
    
    # Get item_types 'made'
    my @item_types_made = $shop->item_types_made;

    # Get a sorted list of categories
    my @categories = $c->model('Item_Category')->search(
    	{},
    	{
    		order_by => 'item_category',
    	},
    );
    
    my %items;
    
    # Put everything into a hash by category
    foreach my $item (@items) {
    	push @{$items{$item->item_type->category->item_category}{item}}, $item;	
    }
    
    foreach my $item_type (@item_types_made) {
    	push @{$items{$item_type->category->item_category}{item_type}}, $item_type;	
    }
    
    # TODO: sort %items?    
       
    $c->forward('RPG::V::TT',
        [{
            template => 'shop/purchase.html',
            params => {
                shop => $shop,
                characters => \@characters,
                shops_in_town => \@shops_in_town,
                items => \%items,
                gold => $party->gold,
            }
        }]
    );
}

sub buy_item : Local {
    my ($self, $c) = @_;
    
    my $item = $c->model('Items')->find({
    	item_id => $c->req->param('item_id'),
    });
	
    my $party = $c->stash->{party};
    
    # TODO: deal with item being bought by another party
    my $town = $item->in_shop->in_town;
    
    if ($town->id != 0 && $town->id != $party->location->town->id) {
    	$c->res->body(to_json({error => "Attempting to buy an item in another town"}));
    	# TODO: this does allow them to buy items from a different shop, which may or may not be OK
   		return;	
    }  
    
    my $cost = $item->item_type->modified_cost($item->in_shop);
    
    if ($party->gold < $cost) {
        $c->res->body(to_json({error => "Your party doesn't have enough gold to buy this item"}));
        return;        
    }
    
    my $shop_id = $item->shop_id;
    
    $item->character_id($c->req->param('character_id'));
    $item->shop_id(undef);
    $item->update;
    
    $party->gold($party->gold - $cost);
    $party->update;
    
    # Find the next item id for this item type in the shop (if any)
    my $item_rs = $c->model('Items')->search({
    	shop_id => $shop_id,
    	item_type_id => $item->item_type_id,
    });

	my $next_item = $item_rs->first;   
    my $next_item_id = $next_item ? $next_item->id : undef;
    
    my $ret = to_json(
    	{
    		gold => $party->gold, 
    		updated_stock => {
    			item_type => $item->item_type->id,
    			next_item_id => $next_item_id,
    			count => $item_rs->count,	
    		},
    	},
	);
        
    $c->res->body($ret);
}

# TODO: fair bit of duplication between this and buy_item
sub buy_quantity_item : Local {
    my ($self, $c) = @_;
    
    my $item_type = $c->model('Item_Type')->find({
    	item_type_id => $c->req->param('item_type_id'),
    });

	my $party = $c->stash->{party};

	# Make sure the shop they're in checks out	
	my $shop = $c->model('Shop')->find(
		{
			shop_id => $c->req->param('shop_id'),
			'items_made.item_type_id' => $c->req->param('item_type_id'),
		},
		{
			join => 'items_made',
		},
	);
	
	unless ($shop) {
		$c->res->body(to_json({error => "Attempting to buy an item type not in this shop"}));
		return;
	}

	# Make sure the shop they're in is in the town they're in
    if ($shop->town_id != 0 && $shop->town_id != $party->location->town->id) {
    	$c->res->body(to_json({error => "Attempting to buy an item in another town"}));
    	# TODO: this does allow them to buy items from a different shop, which may or may not be OK
   		return;	
    }
    
    my $cost = $item_type->modified_cost($shop) * $c->req->param('quantity');
    
    if ($party->gold < $cost) {
        $c->res->body(to_json({error => "Your party doesn't have enough gold to buy this item"}));
        return;        
    }
    
    # Create the item
    my $item = $c->model('Items')->create({
    	item_type_id => $c->req->param('item_type_id'),
    });
    
    $item->variable('Quantity', $c->req->param('quantity'));    
    $item->character_id($c->req->param('character_id'));
    $item->update;
    
    $party->gold($party->gold - $cost);
    $party->update;    
    
    my $ret = to_json(
    	{
    		gold => $party->gold,
    	}
    ); 
    
    $c->res->body($ret);
}

sub sell_item : Local {
	my ($self, $c) = @_;
	
	my $item = $c->model('Items')->find({
		item_id => $c->req->param('item_id'),
	});
	
	# Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    if (scalar (grep { $_->id eq $item->character_id } @characters) == 0) {
    	$c->log->warn("Attempted to sell item " . $item->id . " by party " . $c->stash->{party}->id . 
    		", but item does not belong to this party (item is owned by character: " . $item->character_id . ")");
    	return;	
    }
    
    my $shop = $c->model('Shop')->find({
    	shop_id => $c->req->param('shop_id'),
    });
    
    # Make sure the shop they're in is in the town they're in
    if ($shop->town_id != 0 && $shop->town_id != $c->stash->{party}->location->town->id) {
    	$c->res->body(to_json({error => "Attempting to sell an item in another town"}));
    	# TODO: this does allow them to sell items from a different shop, which may or may not be OK
   		return;	
    }
    
    $c->stash->{party}->gold($c->stash->{party}->gold + $item->sell_price($shop));
    $c->stash->{party}->update;
    
    $item->character_id(undef);
    $item->equip_place_id(undef);
    


    if ($item->variable('Quantity')) {
		# Qunatity itmes get deleted
		$item->delete;
    }
    else {
        # If it's not a quantity item, give it back to the shop
    	$item->shop_id($shop->id);        	
    	$item->update;
    }
 
    my $ret = to_json(
    	{
    		gold => $c->stash->{party}->gold,
    	}
    ); 
    
    $c->res->body($ret);   
    
     
}

1;