package RPG::C::Shop;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;

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

sub buy : Local {
    my ($self, $c) = @_;
    
    my $item_type = $c->model('Item_Type')->find( $c->req->param('item_type_id') );
    my $party = $c->stash->{party};
    
    if ($party->gold < $item_type->base_cost) {
        $c->res->body(jsdump(error => "Your party doesn't have enough gold to buy this item"));
        return;        
    }
        
    my $item = $c->model('DBIC::Items')->create({
        item_type_id => $c->req->param('item_type_id'),
        character_id => $c->req->param('character_id'),
    });
    
    $party->gold($party->gold - $item_type->base_cost);
    $party->update;
    
    my $ret = jsdump(gold => $party->gold) . jsdump(character_id => $c->req->param('character_id'));
        
    $c->res->body($ret);
}

1;