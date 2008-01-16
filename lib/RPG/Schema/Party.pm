package RPG::Schema::Party;
use base 'DBIx::Class';
use strict;
use warnings;

use Data::Dumper;

__PACKAGE__->load_components(qw/ Core/);
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
      'size' => 0
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

sub movement_factor {
	my $self = shift;

	# TODO: cache this value so we don't have to query multiple times
	my ($rec) = $self->result_source->schema->resultset('Character')->search(
		{
			party_id => $self->id,
		},
		{
			select => { avg => 'constitution' },
			as => 'avg_con',
		}
	);
	
	return int $rec->get_column('avg_con') / 3;
}

1;