package RPG::Schema::Party;

use Moose;

extends 'DBIx::Class';

use Data::Dumper;
use List::Util qw(sum);
use Math::Round qw(round);
use DateTime;

use RPG::Exception;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Numeric Core/);
__PACKAGE__->table('Party');

__PACKAGE__->resultset_class('RPG::ResultSet::Party');

__PACKAGE__->add_columns(
    'party_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 1,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'party_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'player_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'player_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'land_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'land_id',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'name' => {
        'data_type'         => 'blob',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'name',
        'is_nullable'       => 0,
        'size'              => 0
    },
    'gold' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'gold',
        'is_nullable'       => 0,
        'size'              => 0
    },
    'turns' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'turns',
        'is_nullable'       => 0,
        'size'              => 0,
        'accessor'          => '_turns',
    },
    'in_combat_with' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'in_combat_with',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'rank_separator_position' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'rank_separator_position',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'rest' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'rest',
        'is_nullable'       => 0,
        'size'              => 0
    },
    'created' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'created',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'turns_used' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'turns_used',
        'is_nullable'       => 1,
        'size'              => 0,
    },
    'defunct' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'defunct',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'last_action' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'last_action',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'dungeon_grid_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'dungeon_grid_id',
        'is_nullable'       => 0,
        'size'              => 0,
    },
    'flee_threshold' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'flee_threshold',
        'is_nullable'       => 0,
        'size'              => 0,
    },
    'combat_type' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'combat_type',
        'is_nullable'       => 0,
        'size'              => 255
    },    
);
__PACKAGE__->set_primary_key('party_id');

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', 'party_id', );

__PACKAGE__->has_many( 'day_logs', 'RPG::Schema::DayLog', 'party_id', );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->belongs_to( 'cg_opponent', 'RPG::Schema::CreatureGroup', { 'foreign.creature_group_id' => 'self.in_combat_with' } );

__PACKAGE__->belongs_to( 'player', 'RPG::Schema::Player', { 'foreign.player_id' => 'self.player_id' } );

__PACKAGE__->has_many( 'quests', 'RPG::Schema::Quest', 'party_id', );

__PACKAGE__->has_many( 'party_battles', 'RPG::Schema::Battle_Participant', 'party_id', );

__PACKAGE__->has_many( 'party_effects', 'RPG::Schema::Party_Effect', 'party_id', );

__PACKAGE__->has_many( 'party_towns', 'RPG::Schema::Party_Town', 'party_id', );

__PACKAGE__->might_have( 'dungeon_location', 'RPG::Schema::Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->has_many( 'garrisons', 'RPG::Schema::Garrison', 
	{ 'foreign.party_id' => 'self.party_id' },
	{ where => {'land_id' => {'!=', undef}} }, 
);

__PACKAGE__->numeric_columns(qw/gold/); # Can't use this for turns..

with qw/
	RPG::Schema::Role::BeingGroup
	RPG::Schema::Role::CharacterGroup
/;

sub members {
    my $self = shift;

    return $self->characters_in_party;
}

sub group_type {
	return 'party';	
}

sub movement_factor {
    my $self = shift;

    my $avg_con = $self->average_stat('constitution');

	my $base_mf = int $avg_con / 4; 

    return $base_mf;
}

sub after_land_move {
    my $self = shift;
    my $land = shift;

    $self->turns( $self->turns - $land->movement_cost( $self->movement_factor, undef, $self->location ) );
}

sub current_location {
	my $self = shift;
	
	return $self->location;
}

sub characters_in_party {
	my $self = shift;
	
	return $self->search_related('characters',
		{
			'garrison_id' => undef,
			'mayor_of' => undef,
		},
		{
			'order_by' => 'party_order',
		},
	);
}

sub characters_in_sector {
	my $self = shift;
	
	my @chars = $self->characters_in_party;
	
	my $garrison = $self->location->garrison;
	if ($garrison && $garrison->party_id == $self->id) {
		push @chars, $garrison->characters;
	}
	
	return @chars;		
}

# Record turns used whenever number of turns are decreased
sub turns {
    my $self      = shift;
    my $new_turns = shift;

    return $self->_turns unless defined $new_turns;

    if ( $new_turns > $self->_turns ) {
        die RPG::Exception->new(
            message => "Turns must be increased by calling increase_turns() method",
            type    => 'increase_turns_error',
        );
    }

    # Update the day's turns used
    my $turns_used = $self->_turns - $new_turns;

    # XXX: the turns used might not be 100% accurate, because two separate parties could read the same value from the day table, and commit their
    #  changes separately.
    my $day = $self->result_source->schema->resultset('Day')->find_today;
    
    confess "Can't find today" unless $day;
    
    $day->turns_used( ( $day->turns_used || 0 ) + $turns_used );
    $day->update;

    # No need to call update, since something else will call it to update the new turns value
    $self->turns_used( ( $self->turns_used || 0 ) + $turns_used );

    $self->_turns($new_turns);
}

sub increase_turns {
    my $self      = shift;
    my $new_turns = shift;

    return unless defined $new_turns;

    if ( $new_turns < $self->_turns ) {
        die RPG::Exception->new(
            message => "Turns must be decreased by calling turns() method",
            type    => 'increase_turns_error',
        );
    }

    $new_turns = RPG::Schema->config->{maximum_turns} if $new_turns > RPG::Schema->config->{maximum_turns};

    $self->_turns($new_turns);
}

sub average_stat {
    my $self = shift;
    my $stat = shift;

    return $self->result_source->schema->resultset('Party')->average_stat( $self->id, $stat );
}

sub new_day {
    my $self    = shift;
    my $new_day = shift;

    my @log;    # TODO: should be a template

    $self->increase_turns( $self->turns + RPG::Schema->config->{daily_turns} );

    push @log, "You now have " . $self->turns . " turns.";

    foreach my $character ( $self->characters ) {
        next if $character->is_dead;

		my $rest = $character->garrison_id ? 3 : $self->rest;

        # Heal chars based on amount of rest they've had during the day
        if ( $rest != 0 ) {
        	my $percentage_to_heal = RPG::Schema->config->{min_heal_percentage} + $rest * RPG::Schema->config->{max_heal_percentage} / 10;
        	
            my $hp_increase = round $character->max_hit_points * $percentage_to_heal / 100;
            $hp_increase = 1 if $hp_increase == 0;    # Always a min of 1

            my $actual_increase = $character->change_hit_points($hp_increase);

            push @log, $character->name . " was rested, and healed " . $actual_increase . " hit points"
                if $actual_increase > 0;
        }

        # Memorise new spells for the day
        my $spell_count = $character->rememorise_spells();

        push @log, $character->name . " has $spell_count spells memorised"
            if $spell_count > 0;

        $character->update;
    }

    # They're no longer rested
    $self->rest(0);
    $self->update;

    $self->add_to_day_logs(
        {
            day_id => $new_day->id,
            log    => join( "\n", @log ),
        }
    );

    return;
}

sub number_alive {
    my $self = shift;

    return $self->result_source->schema->resultset('Character')->count(
        {
            hit_points => { '>', 0 },
            party_id   => $self->id,
            garrison_id => undef,
            mayor_of => undef,
        }
    );
}

# Adjust party order numbers to make sure they're contiguous
sub adjust_order {
    my $self = shift;

    my $count = 0;
    foreach my $character ( $self->characters_in_party ) {
        $character->discard_changes;
        next unless $character->in_storage && $character->party_id == $self->id;

        $count++;
        $character->party_order($count);
        $character->update;
    }
    
    # Reset rank bar if it's gone off edge of party
    if ($self->rank_separator_position >= $count) {    	
    	my $new_pos = $count-1;
    	$new_pos = 1 if $new_pos <= 0;
    	$self->rank_separator_position($new_pos);
    	$self->update;
    }
}

sub summary {
    my $self                    = shift;
    my $include_dead_characters = shift || 0;
    my @characters              = $self->characters_in_party;

    my %summary;

    foreach my $character (@characters) {
        next if !$include_dead_characters && $character->is_dead;
        $summary{ $character->class->class_name }++;
    }

    return \%summary;
}

sub in_combat {
    my $self = shift;

    return $self->in_combat_with || $self->in_party_battle;
}

sub in_party_battle {
    my $self = shift;

    return $self->_get_party_battle ? 1 : 0;
}

sub initiate_combat {
	my $self = shift;
	my $opponent = shift;
	
	$self->in_combat_with($opponent->id);
	$self->combat_type($opponent->group_type);
	$self->update;	
}

sub in_party_battle_with {
    my $self = shift;

    my $battle = $self->_get_party_battle;

    if ($battle) {
        my $battle_participant = $self->result_source->schema->resultset('Battle_Participant')->find(
            {
                party_id  => { '!=', $self->id },
                battle_id => $battle->battle->battle_id,
            },
            { prefetch => { 'party' => { 'characters' => 'character_effects' } }, },
        );

        return $battle_participant->party;
    }

    return;
}

sub _get_party_battle {
    my $self = shift;

    return $self->{_party_battle} if defined $self->{_party_battle};

    my $battle = $self->find_related( 'party_battles', { 'battle.complete' => undef, }, { prefetch => 'battle', } );

    $self->{_party_battle} = $battle;

    return $battle;
}

sub end_combat {
    my $self = shift;

    $self->in_combat_with(undef);
	$self->combat_type(undef);
	$self->update;

    my $party_battle = $self->_get_party_battle;

    if ($party_battle) {
        $party_battle->battle->update( { complete => DateTime->now() } );
        undef $self->{_party_battle};
    }
}

sub is_online {
    my $self = shift;
    
    return $self->last_action >= DateTime->now()->subtract( minutes => RPG::Schema->config->{online_threshold} ) ? 1 : 0;
}

sub quests_in_progress {
    my $self = shift;

    return $self->search_related( 'quests', { status => 'In Progress', } );
}

sub prestige_for_town {
    my $self = shift;
    my $town = shift;
    
    my $party_town = $self->find_related(
        'party_towns',
        {

            town_id  => $town->id,
        },
    );
    
    return $party_town ? $party_town->prestige : 0;    
}

sub has_overencumbered_character {
	my $self = shift;
	
	my @characters = $self->characters;
		
	my $over_encumbered_characters = grep { $_->is_overencumbered } @characters;
	
	return $over_encumbered_characters;	
}

sub allowed_more_quests {
	my $self = shift;
	
    my $party_quests_rs = $self->search_related(
    	'quests',
        {
            status   => 'In Progress',
        },
    );

    my $number_of_quests_allowed = RPG::Schema->config->{base_allowed_quests} + ( RPG::Schema->config->{additional_quests_per_level} * $self->level );

    return $party_quests_rs->count >= $number_of_quests_allowed ? 0 : 1;
}

# Called when party is disbanded or wiped out
sub disband {
	my $self = shift;
	
	$self->defunct(DateTime->now());
	$self->update;
	
	# Turn any mayors into NPCs
	$self->search_related(
		'characters',
		{
			mayor_of => {'!=', undef},
		},
	)->update(
		{
			'party_id' => undef,
		}
	);	
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);


1;
