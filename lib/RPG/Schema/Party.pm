package RPG::Schema::Party;
use base 'DBIx::Class';
use strict;
use warnings;

use Data::Dumper;
use List::Util qw(sum);
use Math::Round qw(round);
use POSIX;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Party');

__PACKAGE__->resultset_class('RPG::ResultSet::Party');

__PACKAGE__->add_columns(
    'party_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'party_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'player_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'player_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'land_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'land_id',
      'is_nullable' => 1,
      'size' => '11'
    },
    'name' => {
      'data_type' => 'blob',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'name',
      'is_nullable' => 0,
      'size' => 0
    },
    'gold' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'gold',
      'is_nullable' => 0,
      'size' => 0
    },
    'turns' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'turns',
      'is_nullable' => 0,
      'size' => 0,
      'accessor' => '_turns',
    },
    'in_combat_with' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'in_combat_with',
      'is_nullable' => 1,
      'size' => 0
    },    
    'rank_separator_position' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'rank_separator_position',
      'is_nullable' => 1,
      'size' => 0
    }, 
    'rest' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'rest',
      'is_nullable' => 0,
      'size' => 0
    },
    'created' => {
      'data_type' => 'datetime',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'created',
      'is_nullable' => 1,
      'size' => 0
    },
    'turns_used' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'turns_used',
      'is_nullable' => 1,
      'size' => 0,
    },
    'new_day_due' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'new_day_due',
      'is_nullable' => 0,
      'size' => 0,
    },
);
__PACKAGE__->set_primary_key('party_id');

__PACKAGE__->has_many(
    'characters',
    'RPG::Schema::Character',
    'party_id',
);

__PACKAGE__->has_many(
    'day_logs',
    'RPG::Schema::DayLog',
    'party_id',
);

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

__PACKAGE__->might_have(
    'cg_opponent',
    'RPG::Schema::CreatureGroup',
    { 'foreign.creature_group_id' => 'self.in_combat_with' }
);

__PACKAGE__->belongs_to(
    'owned_by_player',
    'RPG::Schema::Player',
    { 'foreign.player_id' => 'self.player_id' }
);

sub movement_factor {
	my $self = shift;
	
	return $self->{_movement_factor} if defined $self->{_movement_factor};

	my $avg_con = $self->average_stat('constitution');
	
	$self->{_movement_factor} = int $avg_con / 3;
	
	return $self->{_movement_factor};
}

sub level {
	my $self = shift;
	
	my (@characters) = $self->characters;
	
	return int _median( map { $_->level } @characters ); 	
}

sub _median {
	sum( ( sort { $a <=> $b } @_ )[ int( $#_/2 ), ceil( $#_/2 ) ] )/2;
}

# Recored turns used whenever number of turns are decreased
sub turns {
	my $self = shift;
	my $new_turns = shift;
	
	return $self->_turns unless defined $new_turns;
	
	# only do it if turns are decreaed
	if ($new_turns < $self->_turns) {
		$self->turns_used($self->turns_used + ($self->_turns - $new_turns));
		# No need to call update, since something else will call it to update the new turns value
	}
	
	$self->_turns($new_turns);
}

sub average_stat {
	my $self = shift;
	my $stat = shift;
	
	return $self->result_source->schema->resultset('Party')->average_stat($self->id, $stat);	
}

sub new_day {
	my $self = shift;
	my $new_day = shift;
	
	my @log; # TODO: should be a template

	$self->turns($self->turns + RPG::Schema->config->{daily_turns});
	$self->turns(RPG::Schema->config->{maximum_turns}) if $self->turns > RPG::Schema->config->{maximum_turns};
		
	push @log, "You now have " . $self->turns . " turns.";

	my $percentage_to_heal = RPG::Schema->config->{min_heal_percentage} + $self->rest * RPG::Schema->config->{max_heal_percentage} / 10;

	foreach my $character ($self->characters) {
		next if $character->is_dead;
		
		# Heal chars based on amount of rest they've had during the day
		if ($self->rest != 0) {
			my $hp_increase = round $character->max_hit_points * $percentage_to_heal / 100;
			$hp_increase = 1 if $hp_increase == 0; # Always a min of 1
			
			push @log, $character->name . " was rested, and healed " . $hp_increase . " hit points";
			
			$character->change_hit_points($hp_increase);
		}
				
		# Memorise new spells for the day
		my @spells_to_memorise = $character->memorised_spells;
		
		push @log, $character->name . " has " . scalar @spells_to_memorise . " spells memorised"
			if @spells_to_memorise;
		
		foreach my $spell (@spells_to_memorise) {
			if ($spell->memorise_tomorrow) {
				$spell->memorised_today(1);
				$spell->memorise_count($spell->memorise_count_tomorrow);
				$spell->number_cast_today(0);
				$spell->update;
			}
			else {
				# Spell no longer memorised, so delete the record
				$spell->delete;	
			}	
		}
				
		$character->update;
	}
		
	# They're no longer rested
	$self->rest(0);
	$self->update;
		
	$self->add_to_day_logs(
		{
			day_id => $new_day->id,
			log => join "\n", @log,
		}
	);
	
	return;
}

1;