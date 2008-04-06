package RPG::C::Shop;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

sub purchase : Local {
    my ($self, $c) = @_;
    
    my $shop = $c->model('DBIC::Shop')->find($c->req->param('shop_id'));

    my @categories; # = $shop->categories_sold;
    
    my $party = $c->stash->{party};

    my @characters = $party->characters;
    
    my @items = $shop->grouped_items_in_shop;
    #warn Dumper $itmems[0];
        
    $c->forward('RPG::V::TT',
        [{
            template => 'shop/purchase.html',
            params => {
                shop => $shop,
                categories => \@categories,
                characters => \@characters,
                items => \@items,
                gold => $party->gold,
            }
        }]
    );
}

sub get_items : Local {
    my ($self, $c) = @_;
    
    my $shop = $c->model('DBIC::Shop')->find($c->req->param('shop_id'));
    
    my @categories = $c->model('Item_Type')->search(
        {
            'shops_with_item.shop_id' => $c->req->param('shop_id'),
            'item_category_id' => $c->req->param('category_id'),
        },
        {
            join => ['shops_with_item'],
        }
    );
    
    my @ret_categories = map { 
        {
            item_type_id => $_->id, 
            item_type => $_->item_type,
            cost => int ($_->base_cost * $shop->cost_modifier),
            basic_modifier => $_->basic_modifier,
        }
    } @categories;
    
    my $ret = jsdump(items => \@ret_categories);
    
    $c->res->body($ret);
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

1;