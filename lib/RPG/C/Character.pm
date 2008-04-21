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
	    	prefetch => [
	    		{
	    			'items' => [
	    				{'item_type' => 'category'},
	    				'item_variables',
	    			],
	    		},
	    		'race',
	    		'class',
	    	],
	    	order_by => 'item_category',
	    },
	);
	
	my $equipped_items = $character->equipped_items;
	my @characters = $c->stash->{party}->characters;
    
    $c->forward('RPG::V::TT',
        [{
            template => 'character/view.html',
            params => {
                character => $character,
                equipped_items => $equipped_items,
                characters => \@characters,
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
    
    my $item = $c->model('Items')->find(
    	{
    		item_id => $c->req->param('item_id'),
    	},
    	{
    		prefetch => {'item_type' =>	{'item_attributes' => 'item_attribute_name'}},
    	},
    );
    
    # Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    if (scalar (grep { $_->id eq $item->character_id } @characters) == 0) {
    	$c->log->warn("Attempted to equip item " . $item->id . " by party " . $c->stash->{party}->id . 
    		", but item does not belong to this party (item is owned by character: " . $item->character_id . ")");
    	return;	
    } 
    
    my ($equip_place) = $c->model('DBIC::Equip_Places')->search(
    	{
    		equip_place_name => $c->req->param('equip_place'),
    		'equip_place_categories.item_category_id' => $item->item_type->item_category_id,
    	},
    	{
    		join => 'equip_place_categories',
    	},
    );
    
    # Make sure this category of item can be equipped here
    unless ($equip_place) {
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
    
    # Check to see if we're going to affect the opposite hand's equipped item
    my $other_hand = $equip_place->opposite_hand;
    
    if ($other_hand) {
    	my ($item_in_opposite_hand) = $c->model('Items')->search(
    		{
	    		character_id => $item->character_id,
	    		equip_place_id => $other_hand->id,
	    	},
	    	{
    			prefetch => {'item_type' =>	{'item_attributes' => 'item_attribute_name'}},
    		},
    	);

    	# If we're equipping a two-handed weapon, or there's one already equipped also clear the other hand
	    my $attribute = $item->attribute('Two-Handed');
	    my $opposite_hand_attribute = $item_in_opposite_hand ? $item_in_opposite_hand->attribute('Two-Handed') : undef;
	    if (($attribute && $attribute->value) || ($opposite_hand_attribute && $opposite_hand_attribute->value)) {    	
	    
		    if ($item_in_opposite_hand && $item_in_opposite_hand->id != $item->id) {
		    	$item_in_opposite_hand->equip_place_id(undef);
		    	$item_in_opposite_hand->update;
		    }
	    	
	    	$c->res->body(to_json({clear_equip_place => $other_hand->equip_place_name}));
	    }
    }
    
    # Tell client that item should be unequipped from original place
    #  XXX: Note, we currently expect this not to occur if a two-handed weapon is being equipped, since it should have
    #   been taken care of above (since weapons can only be equipped in the hands) 
    if ($item->equip_place_id) {
    	$c->res->body(to_json({clear_equip_place => $item->equipped_in->equip_place_name}));	
    }
    
    $item->equip_place_id($equip_place->id);
    $item->update;    

}

sub give_item : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('Character')->find(
    	{
    		character_id => $c->req->param('character_id'),
    		party_id => $c->stash->{party}->id,
    	},
    );
    
    # Make sure character being given to is in the party
    unless ($character) {
    	$c->log->warn("Can't find " . $c->req->param('character_id') . " in party " . $c->stash->{party}->id);
    	return;
    }
    
    my $item = $c->model('Items')->find({
    	item_id => $c->req->param('item_id'),
    });
    
    # Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    if (scalar (grep { $_->id eq $item->character_id } @characters) == 0) {
    	$c->log->warn("Attempted to give item  " . $item->id . " within party " . $c->stash->{party}->id . 
    		", but item does not belong to this party (item is owned by character: " . $item->character_id . ")");
    	return;	
    }
    
    $item->character_id($character->id);
    $item->equip_place_id(undef);
    $item->update;
    
    $c->res->body(to_json({message=>"A " . $item->item_type->item_type . " was given to " . $character->character_name})); 
}

# Called by shop screen to get list of equipment.
sub equipment_list : Local {
	my ($self, $c) = @_;
	
	my ($character) = grep { $_->id eq $c->req->param('character_id') } $c->stash->{party}->characters;
	
	# Make sure character is in the party
    unless ($character) {
    	$c->log->warn("Can't find " . $c->req->param('character_id') . " in party " . $c->stash->{party}->id);
    	return;
    }
    
    my $shop = $c->model('Shop')->find({
    	shop_id => $c->req->param('shop_id'),
    });
    
    my @items = $character->items;
        
    $c->forward('RPG::V::TT',
        [{
            template => 'character/equipment_list.html',
            params => {
            	items => \@items,
            	shop => $shop,
            }
        }]
    );        
    
}

1;