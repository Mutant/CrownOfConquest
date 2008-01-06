package RPG::Schema::Terrain;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Terrain');


__PACKAGE__->add_columns(
    'terrain_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'terrain_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'terrain_name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'terrain_name',
      'is_nullable' => 0,
      'size' => '255'
    },
    'image' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'image',
      'is_nullable' => 0,
      'size' => '255'
    },
    'modifier' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'modifier',
      'is_nullable' => 0,
      'size' => '11'
    },
);

__PACKAGE__->set_primary_key('terrain_id');

1;