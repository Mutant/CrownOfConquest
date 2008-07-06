package RPG::C::Character;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;
use JSON;

sub view : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('DBIC::Character')->find(
    	{ 
	        character_id => $c->req->param('character_id'),
	        party_id => $c->stash->{party}->id,
	    },
	    {
	    	prefetch => [
	    		'race',
	    		'class',
	    	],
	    },
	);
	
	my $next_level = $c->model('DBIC::Levels')->find(
		{
			level_number => $character->level + 1,
		}
	);
	
	my @characters = $c->stash->{party}->characters;
    
    $c->forward('RPG::V::TT',
        [{
            template => 'character/view.html',
            params => {
                character => $character,
                characters => \@characters,
                xp_for_next_level => $next_level->xp_needed,
            }
        }]
    );
}

sub equipment_tab : Local {
	my ($self, $c) = @_;
	
    my $character = $c->model('DBIC::Character')->find(
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
	    	],
	    	order_by => 'item_category',
	    },
	);	
	
	my $equipped_items = $character->equipped_items;
	
	my %equip_place_category_list = $c->model('DBIC::Equip_Places')->equip_place_category_list;
	
    $c->forward('RPG::V::TT',
        [{
            template => 'character/equipment_tab.html',
            params => {
                character => $character,
                equipped_items => $equipped_items,
                equip_place_category_list => \%equip_place_category_list,
            }
        }]
    );
}

sub item_list : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('DBIC::Character')->find({ 
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
    
	my %ret;
    
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
	    	
	    	%ret = (clear_equip_place => $other_hand->equip_place_name);
	    }
    }
    
    # Tell client that item should be unequipped from original place
    #  XXX: Note, we currently expect this not to occur if a two-handed weapon is being equipped, since it should have
    #   been taken care of above (since weapons can only be equipped in the hands) 
	%ret = (clear_equip_place => $item->equipped_in->equip_place_name) if $item->equip_place_id;
    
    $c->res->body(to_json(\%ret));
    
    $item->equip_place_id($equip_place->id);
    $item->update;    

}

sub give_item : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('DBIC::Character')->find(
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

sub spells_tab : Local {
	my ($self, $c) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
    	{ 
	        character_id => $c->req->param('character_id'),
	        party_id => $c->stash->{party}->id,
	    },
	);
	
	return unless $character;
	
    my @memorised_spells = $c->model('Memorised_Spells')->search(
    	{ 
	        character_id => $c->req->param('character_id'),
	    },
	    {
	    	prefetch => 'spell',
	    },
	);
	
	my @available_spells = $c->model('DBIC::Spell')->search(
		{
			class_id => $character->class_id,
		},
		{
			order_by => 'spell_name',
		},
	);
	
    $c->forward('RPG::V::TT',
        [{
            template => 'character/spells_tab.html',
            params => {
            	character => $character,
                memorised_spells => \@memorised_spells,
				available_spells => \@available_spells,
            }
        }]
    );
    
}

sub memorise_spell : Local {
	my ($self, $c) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
    	{ 
	        character_id => $c->req->param('character_id'),
	        party_id => $c->stash->{party}->id,
	    },
	);
	
	return unless $character;
	
	my $spell = $c->model('DBIC::Spell')->find(
		{
			spell_id => $c->req->param('spell_id'),
		},
	);
	
	return unless $spell;
			
	if ($spell->points > $character->spell_points - $character->spell_points_used) {
		$c->stash->{error} = $character->character_name . " doesn't have enough spell points to memorise " . $spell->spell_name;	
	}
	else {
		my $memorised_spell = $c->model('Memorised_Spells')->find_or_create(
			{
				character_id => $character->id,
				spell_id => $spell->id,				
			},
		);
		
		$memorised_spell->memorise_tomorrow(1);
		$memorised_spell->memorise_count_tomorrow($memorised_spell->memorise_count_tomorrow+1);
		$memorised_spell->update;
	}
	
	$c->forward('/character/view');
}

sub unmemorise_spell : Local {
	my ($self, $c) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
    	{ 
	        character_id => $c->req->param('character_id'),
	        party_id => $c->stash->{party}->id,
	    },
	);
	
	return unless $character;
	
	my $spell = $c->model('DBIC::Spell')->find(
		{
			spell_id => $c->req->param('spell_id'),
		},
	);
	
	return unless $spell;	
	
	my $memorised_spell = $c->model('Memorised_Spells')->find(
		{
			character_id => $character->id,
			spell_id => $spell->id,				
		},
	);
	
	$memorised_spell->memorise_count_tomorrow($memorised_spell->memorise_count_tomorrow-1)
		if $memorised_spell->memorise_count_tomorrow != 0;
	$memorised_spell->memorise_tomorrow(0)
		if $memorised_spell->memorise_count_tomorrow == 0;
	$memorised_spell->update;
	
	$c->forward('/character/view');
}

sub add_stat_point : Local {
	my ($self, $c) = @_;	
	
	my $character = $c->model('DBIC::Character')->find(
    	{ 
	        character_id => $c->req->param('character_id'),
	        party_id => $c->stash->{party}->id,
	    },
	);
	
	$c->res->body(to_json({error => 'No stat points to add'})), return
		unless $character->stat_points;
		
	if (my $stat = $character->get_column($c->req->param('stat'))) {
		$character->set_column($c->req->param('stat'), $stat+1);
		$character->stat_points($character->stat_points - 1);
		$character->update;
	}
	
	# Need to return something so caller knows it was successful 
	$c->res->body(to_json({}));
}

1;