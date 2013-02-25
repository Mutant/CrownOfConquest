package RPG::Schema::CreatureGroup;

use Moose;

extends 'DBIx::Class';

with 'RPG::Schema::Role::BeingGroup';

use Carp;
use Data::Dumper;

use List::Util qw(shuffle);

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature_Group');

__PACKAGE__->resultset_class('RPG::ResultSet::CreatureGroup');

__PACKAGE__->add_columns(qw/creature_group_id land_id trait_id dungeon_grid_id/);

__PACKAGE__->set_primary_key('creature_group_id');

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->belongs_to( 'dungeon_grid', 'RPG::Schema::Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->might_have( 'in_combat_with', 'RPG::Schema::Party', { 'foreign.in_combat_with' => 'self.creature_group_id' } );

__PACKAGE__->has_many( 'creatures', 'RPG::Schema::Creature', { 'foreign.creature_group_id' => 'self.creature_group_id' }, );

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', 'creature_group_id' );

has 'melee_weapons' => ( is => 'ro', isa => 'ArrayRef', init_arg => undef, builder => '_build_melee_weapons', lazy => 1, );

sub _build_melee_weapons {
	my $self = shift;
	
	return [$self->result_source->schema->resultset('Item_Type')->search( { 'category.item_category' => 'Melee Weapon', }, { join => 'category', } )];	
}

sub members {
	my $self = shift;

	return ($self->creatures, $self->characters);
}

sub group_type {
	return 'creature_group';
}

sub current_location {
	my $self = shift;

	return $self->location;
}

sub is_online {
	return 0;	
}

sub initiate_combat {
	my $self = shift;
	my $party = shift || croak "Party not supplied";
	my $no_high_level_check = shift // 0;

	if ( $self->land_id && $self->location->orb && $self->location->orb->can_destroy( $party->level ) ) {

		# Always attack if there's an orb in the sector, and the party is high enough level to destroy it
		return 1;
	}

	return 0 unless $self->party_within_level_range($party, $no_high_level_check);

	my $chance = RPG::Schema->config->{creature_attack_chance};

	my $roll = Games::Dice::Advanced->roll('1d100');

	return $roll < $chance ? 1 : 0;
}

sub party_within_level_range {
	my $self = shift;
	my $party = shift || croak "Party not supplied";
	my $no_high_level_check = shift // 0;

	if ( $self->level >= $party->level ) {
		my $factor_comparison = $self->compare_to_party($party);

		#warn $factor_comparison;
		#warn RPG::Schema->config->{cg_attack_max_factor_difference};
		return 0
			if $factor_comparison < RPG::Schema->config->{cg_attack_max_factor_difference};
	}

	# Won't attack party if they're too high a level
	if ( ! $no_high_level_check && $self->level < $party->level ) {
		return 0
			if $party->level - $self->level > RPG::Schema->config->{cg_attack_max_level_below_party};
	}

	return 1;
}

sub creature_summary {
	my $self                   = shift;
	my $include_dead_creatures = shift || 0;
	my @beings                 = $self->members;

	my %summary;

	foreach my $being (@beings) {
		next if !$include_dead_creatures && $being->is_dead;
		my $type = $being->is_character ? $being->class->class_name : $being->type->creature_type;
		$summary{ $type }++;
	}

	return \%summary;
}

sub number_alive {
	my $self = shift;
    my %params = @_;

	# TODO: possibly check if creatures are already loaded, and use those rather than going to the DB

	my $crets_alive = $params{characters_only} ? 0 : $self->result_source->schema->resultset('Creature')->count(
		{
			hit_points_current => { '>', 0 },
			creature_group_id  => $self->id,
		}
	);

	my $chars_alive = $self->result_source->schema->resultset('Character')->count(
		{
			hit_points => { '>', 0 },
			creature_group_id  => $self->id,
		}
	);
	
	return $crets_alive + $chars_alive;

}

sub level {
	my $self = shift;

	return $self->{level} if $self->{level};

	my @creatures = $self->members;

	return 0 unless @creatures;

	my $level_aggr = 0;
	foreach my $creature (@creatures) {
		$level_aggr += $creature->level;
	}

	$self->{level} = int( $level_aggr / scalar @creatures );

	return $self->{level};

}

sub add_creature {
	my $self = shift;
	my $type = shift;
	my $count = shift // $self->number_alive+1;

    confess "Type not supplied" unless $type;

	my $hps = Games::Dice::Advanced->roll( $type->level . 'd8' );
	
	# Extra HPs for rare monsters
	if ($type->rare) {
	   $hps += $type->level * 15;
	}
	
	my $melee_weapons = $self->melee_weapons;

	my $weapon = 'Claws';
	if ( $type->weapon eq 'Melee Weapon' ) {
		my $weapon_rec = ( shuffle @$melee_weapons )[0];
		$weapon = $weapon_rec->item_type;
	}
	else {
		$weapon = $type->weapon;
	}

	$self->add_to_creatures(
		{
			creature_type_id   => $type->id,
			hit_points_current => $hps,
			hit_points_max     => $hps,
			group_order        => $count,
			weapon             => $weapon,
		}
	);
}

sub has_rare_monster {
    my $self = shift;
    
    return $self->search_related('creatures',
        {
            'type.rare' => 1,
            'hit_points_current' => {'>', 0},
        },
        {
            'join' => 'type',
        }
    )->count >= 1 ? 1 : 0;   
}

sub has_mayor {
    my $self = shift;
    
    return $self->search_related('characters',
        {
            'mayor_of' => {'!=', undef},
        },
    )->count >= 1 ? 1 : 0;          
}

# Auto heal the group if they have a mayor, and have some budget to heal
#  (called at the end of combat)
sub auto_heal {
    my $self = shift;
    my $reason = shift // 'combat';

    my $mayor = $self->find_related('characters',
        {
            'mayor_of' => {'!=', undef},
        },
    );
    
    return if ! $mayor;

    my $town = $mayor->mayor_of_town;
    
    return unless $town->character_heal_budget > 0;
    
    my $schema = $self->result_source->schema;
    
    my $day = $schema->resultset('Day')->find_today;
    
    my $hist_rec = $schema->resultset('Town_History')->find_or_create(
        {
            town_id => $town->id,
            day_id => $day->id,
            type => 'expense',
            message => 'Town Garrison Healing',
        }
    );
    
    my $spent = $hist_rec->value // 0;

    return if $spent >= $town->character_heal_budget;
    
    my $budget_left = $town->character_heal_budget - $spent;
    $budget_left = $town->gold if $budget_left > $town->gold;
    
    # Heal the mayor first 
    my @characters = ($mayor, grep { $_->id != $mayor->id } $self->characters);
        
    my $cost_per_hp = $town->heal_cost_per_hp;

    foreach my $character (@characters) {
        next if $character->is_dead;
        
        my $to_heal = $character->max_hit_points - $character->hit_points;
        
        next if $to_heal <= 0;
        
        my $cost = $to_heal * $cost_per_hp;
        
        if ($cost > $budget_left) {
            $to_heal = int $budget_left / $cost_per_hp;
            $cost = $to_heal * $cost_per_hp;
        }
        
        RPG::Schema->log->debug("Auto-Healing char " . $character->id . " for $to_heal hps, costing $cost gold"); 
        
        $character->increase_hit_points($to_heal);
        $character->update;
        
        $budget_left-=$cost;
        $spent+=$cost;
        
        $town->decrease_gold($cost);       
    }
    
    $town->add_to_history(
    	{
			type => 'mayor_news',
			message => "The town garrison was healed for the cost of $spent gold " . ($reason eq 'combat' ? "after combat" : "overnight"),
			day_id => $day->id,
		}
	);
    
    $town->update;
    $hist_rec->value($spent);
    $hist_rec->update;
    
}


sub in_combat {
    my $self = shift;
    
    return $self->in_combat_with ? 1 : 0;
}

sub flee_chance {
    my $self = shift;
    my $opponents = shift;
    
    my $level_diff = $opponents->level - $self->level;
    
	my $chance_of_fleeing = ( $level_diff - 2 ) * RPG::Schema->config->{chance_creatures_flee_per_level_diff};
	
	$chance_of_fleeing += $level_diff if $level_diff > 7;

    my $opp_skill_penalty = $opponents->skill_aggregate('Tactics', 'opponent_flee') // 0;
    $chance_of_fleeing -= $opp_skill_penalty;

    my $skill_bonus = $self->skill_aggregate('Strategy', 'flee_bonus') // 0;
    $chance_of_fleeing += $skill_bonus;
		
    $chance_of_fleeing = 75 if $chance_of_fleeing > 75; 
    
    $chance_of_fleeing = 0 if $chance_of_fleeing < 0;
    
    return $chance_of_fleeing;   
       
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
