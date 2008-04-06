package RPG::C::Character;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;
use JSON;

sub view : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('Character')->find(
    	{ 
	        character_id => $c->req->param('character_id'),
	        party_id => $c->stash->{party}->id,
	    },
	    {
	    	prefetch => [qw/items race class/],
	    	distinct => 1,
	    },
	);
	
	my $equipped_items = $character->equipped_items;
    
    $c->forward('RPG::V::TT',
        [{
            template => 'character/view.html',
            params => {
                character => $character,
                equipped_items => $equipped_items,
            }
        }]
    );
}

sub item_list : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('Character')->find({ 
        character_id => $c->req->param('character_id'),
        party_id => $c->stash->{party}->id,
    });
    
    my @items = $character->items;
    
    my @items_to_return;
    foreach my $item (@items) {
        push @items_to_return, {
            item_type => $item->item_type->item_type,
            item_id => $item->id,
        };
    }
    
    my $ret = jsdump(characterItems => \@items_to_return);
    
    $c->res->body($ret);
}

sub equip_item : Local {
    my ($self, $c) = @_;
    
    my $item = $c->model('Items')->find({
    	item_id => $c->req->param('item_id'),
    });
    
    # Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    unless (scalar (grep { $_->id eq $item->character_id } @characters) > 0) {
    	$c->log->warn("Attempted to equip item " . $item->id . " by party " . $c->stash->{party}->id . 
    		", but item does not belong to this party (item is owned by character: " . $item->character_id . ")");
    	return;	
    } 
    
    my ($equip_place) = $c->model('Equip_Places')->search({
    	equip_place_name => $c->req->param('equip_place'),
    });
    
    # Make sure this category of item can be equipped here
    warn $equip_place->item_category_id;
    warn $item->item_type->item_category_id;
    unless ($equip_place->item_category_id == $item->item_type->item_category_id) {
    	warn "wrong place :(";
    	$c->res->body(to_json({error => "You can't equip a " . $item->item_type->item_type . " there!"}));
    	return;
    }
    
    # Unequip any already equipped item in that place
    my ($equipped_item) = $c->model('Items')->search({
    	character_id => $item->character_id,
    	equip_place_id => $equip_place->id,
    });
    
    if ($equipped_item) {
    	$equipped_item->equip_place_id(undef);
    	$equipped_item->update;
    }
    
    # Tell client that item should be unequipped from original place
    if ($item->equip_place_id) {
    	$c->res->body(to_json({clear_equip_place => $item->equipped_in->equip_place_name}));	
    }
    
    $item->equip_place_id($equip_place->id);
    $item->update;    

}

1;