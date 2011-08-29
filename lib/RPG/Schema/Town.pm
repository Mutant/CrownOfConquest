use strict;
use warnings;

package RPG::Schema::Town;

use base 'DBIx::Class';

use Carp;

use Math::Round qw(round);
use RPG::ResultSet::RowsInSectorRange;

__PACKAGE__->load_components(qw/Numeric InflateColumn::DateTime Core/);
__PACKAGE__->table('Town');

__PACKAGE__->resultset_class('RPG::ResultSet::Town');

__PACKAGE__->add_columns(qw/town_id town_name land_id prosperity blacksmith_age blacksmith_skill 
						    discount_type discount_value discount_threshold pending_mayor gold peasant_tax
						    party_tax_level_step base_party_tax sales_tax tax_modified_today
						    mayor_rating peasant_state last_election advisor_fee character_heal_budget/);
						    
__PACKAGE__->add_columns(
	pending_mayor_date => {data_type => 'datetime'},
);
						    
__PACKAGE__->numeric_columns(
	peasant_tax => {
		min_value => 0, 
		max_value => 100,
	},
	gold => {
		min_value => 0,
	},
	party_tax_level_step => {
		min_value => 0,
		max_value => 100,
	},		
	base_party_tax => {
		min_value => 0,
		max_value => 100,
	},
	sales_tax => {
		min_value => 0, 
		max_value => 20,
	},
	mayor_rating => {
		min_value => -100,
		max_value => 100,
	},
	prosperity => {
		min_value => 1,
		max_value => 100,
	},
	advisor_fee => {
		min_value => 0,	
	}
); 

__PACKAGE__->set_primary_key('town_id');

__PACKAGE__->has_many( 'shops', 'RPG::Schema::Shop', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->has_many( 'quests', 'RPG::Schema::Quest', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->has_many( 'party_town', 'RPG::Schema::Party_Town', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->might_have( 'castle', 'RPG::Schema::Dungeon', { 'foreign.land_id' => 'self.land_id' }, );

__PACKAGE__->might_have( 'mayor', 'RPG::Schema::Character', { 'foreign.mayor_of' => 'self.town_id' }, );

__PACKAGE__->has_many( 'history', 'RPG::Schema::Town_History', 'town_id', );

__PACKAGE__->has_many( 'elections', 'RPG::Schema::Election', 'town_id', );

__PACKAGE__->might_have( 'current_election', 'RPG::Schema::Election', 'town_id', { where => {'status' => 'Open'}} );

__PACKAGE__->might_have( 'capital_of', 'RPG::Schema::Kingdom', { 'foreign.capital' => 'self.town_id' }, );

sub label {
    my $self = shift;
    
    return $self->town_name . ' (' . $self->location->x . ', ' . $self->location->y . ')';
}

sub tax_cost {
    my $self  = shift;
    my $party = shift;
    my $base_cost = shift;
    my $level_modifier = shift;
    
    my $party_level;
    my $prestige = 0;
    
    my $mayor = $self->mayor;
    if (ref $party && $mayor && defined $mayor->party_id && $mayor->party_id == $party->id) {
    	return { mayor => 1 };	
    }
    
    if (ref $party) {
    	my $party_town_rec = $self->find_related( 'party_town', { 'party_id' => $party->id, }, );

    	if ( $party_town_rec && $party_town_rec->tax_amount_paid_today > 0 ) {
        	return { paid => 1 };
    	}
    	
    	$party_level = $party->level;
    	$prestige = $party_town_rec->prestige if $party_town_rec;
    }
    else {
    	$party_level = $party;
    }    
    
    if (! defined $base_cost && ! defined $level_modifier) {     
	    if ($mayor && $mayor->party_id) {
	    	$base_cost = $self->base_party_tax;
	    	$level_modifier = $self->party_tax_level_step;
	    }
	    else {
	    	$base_cost = $self->prosperity * RPG::Schema->config->{tax_per_prosperity};
	    	$level_modifier = $self->prosperity * RPG::Schema->config->{tax_level_modifier};
	    }
    }
    
    my $level_cost = round ($level_modifier * ($party_level - 1 ));
    
    my $prestige_modifier = (0-$prestige) / 300;

    my $gold_cost = round ($base_cost + $level_cost);
    $gold_cost += round ($gold_cost * $prestige_modifier); 
    $gold_cost = 1 if $gold_cost < 1;

    my $turn_cost = round $gold_cost / RPG::Schema->config->{tax_turn_divisor};

    $turn_cost = 1 if $turn_cost < 1;

    return {
        gold  => $gold_cost,
        turns => $turn_cost,
    };
}

sub has_road_to {
    my $self = shift;
    my $dest_town = shift;
    
    my $found_town = 0;
    
    return $self->_find_roads($self->location, $dest_town->location);
}

sub _find_roads {
    my $self = shift;
    my $start_sector = shift;
    my $dest_sector = shift;
    my $checked = shift || {};
    
    $checked->{$start_sector->id} = 1;
        
    my @surround_sectors = $self->result_source->schema->resultset('Land')->search_for_adjacent_sectors(
        $start_sector->x,
        $start_sector->y,
        3,
        3,        
    );
        
    my @connected_sectors;
    foreach my $sector (@surround_sectors) {
        next if $checked->{$sector->id};
            
        if ($start_sector->has_road_joining_to($sector)) {            
            if ($sector->id == $dest_sector->id) {
                return 1;
            }
            
            push @connected_sectors, $sector;   
        }
    }
    
    foreach my $connected_sector (@connected_sectors) {
        return 1 if $self->_find_roads($connected_sector, $dest_sector, $checked);   
    }
    
    return 0;
}

sub take_sales_tax {
	my $self = shift;
	my $cost = shift;
	
	my $towns_cut = int ($cost * $self->sales_tax / 100);
	$self->increase_gold($towns_cut);
	$self->add_to_history(
		{
			type => 'income',
			value => $towns_cut,
			message => 'Sales Tax',
			day_id => $self->result_source->schema->resultset('Day')->find_today->id,
		}
	);	
}

sub inn_cost {
	my $self = shift;
	my $character = shift || confess "Character not supplied";
	
	return int ($self->prosperity / 10 * $character->level / 4) + 15;	
}

sub expected_garrison_chars_level {
	my $self = shift;
	
	my $expected_garrison_chars_level = 0;
	$expected_garrison_chars_level = 12 if $self->prosperity > 35;
	$expected_garrison_chars_level = 25 if $self->prosperity > 65;
	$expected_garrison_chars_level = 40 if $self->prosperity > 85;
	
	return $expected_garrison_chars_level;
}

sub claim_land {
    my $self = shift;
    
    my $kingdom_id = $self->location->kingdom_id;
    
    return unless $kingdom_id;
    
    my @sectors = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset    => $self->result_source->schema->resultset('Land'),
        relationship => 'me',
        base_point   => {
            x => $self->location->x,
            y => $self->location->y,
        },
        search_range        => RPG::Schema->config->{town_land_claim_range} * 2 + 1,
        increment_search_by => 0,
    );
    
    foreach my $sector (@sectors) {
        # Skip sectors already claimed
        if (defined $sector->claimed_by_type && ($sector->claimed_by_type ne 'town' || $sector->claimed_by_id != $self->id)) {
            next;   
        } 
        
        $sector->kingdom_id($kingdom_id);
        $sector->claimed_by_id($self->id);
        $sector->claimed_by_type('town');
        $sector->update;
    }    
}

sub unclaim_land {
    my $self = shift;   
    
    my @sectors = $self->result_source->schema->resultset('Land')->search(
        {
            'claimed_by_id' => $self->id,
            'claimed_by_type' => 'town',   
        },
    );
    
    foreach my $sector (@sectors) {
        $sector->claimed_by_id(undef);
        $sector->claimed_by_type(undef);
        $sector->update;
    }     
}

sub heal_cost_per_hp {
    my $self = shift;
    
    return round( RPG::Schema->config->{min_healer_cost} + ( 100 - $self->prosperity ) / 100 * RPG::Schema->config->{max_healer_cost} );   
}

sub change_allegiance {
    my $self = shift;
    my $new_kingdom = shift;
    
    my $location = $self->location;
    my $old_kingdom = $location->kingdom;
        
    return if $new_kingdom && $old_kingdom && $new_kingdom->id == $old_kingdom->id;
    
    $location->kingdom_id( $new_kingdom ? $new_kingdom->id : undef );
    $location->update;
    
    $self->decrease_mayor_rating(10);
    $self->unclaim_land;
    $self->claim_land;
    $self->update;

    my $today = $self->result_source->schema->resultset('Day')->find_today;

    # check if this is the most towns the kingdom has had
    if ($new_kingdom && $new_kingdom->highest_town_count < $new_kingdom->towns->count) {
        $new_kingdom->highest_town_count($new_kingdom->towns->count);
        $new_kingdom->highest_town_count_day_id($today->id);
        $new_kingdom->update;
    }
  
    # Leave messages for old/new kings
    if ($new_kingdom) {
        $new_kingdom->add_to_messages(
            {
                message => "The town of " . $self->town_name . " is now loyal to our kingdom.",
                day_id => $today->id,
            }
        );
    }
    if ($old_kingdom) {
        my $message = "The town of " . $self->town_name . " is no longer loyal to our kingdom.";

        # Remove as capital (if it was)
        if ($old_kingdom->capital == $self->id) {
            $old_kingdom->change_capital(undef);
            $message .= ' We no longer have a capital!';
        }
        
        $old_kingdom->add_to_messages(
            {
                message => $message,
                day_id => $today->id,
            }
        );

    }       
}

sub decline_mayoralty {
    my $self = shift;
    
    $self->pending_mayor(undef);
	$self->add_to_history(
		{
			type => 'news',
			message => 'There is currently no mayor. The town is under marshal law.',
			day_id => $self->result_source->schema->resultset('Day')->find_today->id,
		}
	); 
}

1;
