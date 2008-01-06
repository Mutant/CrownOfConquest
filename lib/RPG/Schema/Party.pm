package RPG::Schema::Party;
use base 'DBIx::Class';
use strict;
use warnings;

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
    'movement_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'gold',
      'is_nullable' => 0,
      'size' => 0
    },
);
__PACKAGE__->set_primary_key('party_id');

__PACKAGE__->has_many(
    'characters',
    'RPG::Schema::Character',
    { 'foreign.party_id' => 'self.party_id' }
);

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

1;