package RPG::Schema::Party;
use base 'DBIx::Class';
use strict;
use warnings;

use Data::Dumper;
use List::Util qw(sum);
use POSIX;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Party');

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
);
__PACKAGE__->set_primary_key('party_id');

__PACKAGE__->has_many(
    'characters',
    'RPG::Schema::Character',
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

	my ($rec) = $self->result_source->schema->resultset('Character')->search(
		{
			party_id => $self->id,
		},
		{
			select => { avg => 'constitution' },
			as => 'avg_con',
		}
	);
	
	$self->{_movement_factor} = int $rec->get_column('avg_con') / 3;
	
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

1;