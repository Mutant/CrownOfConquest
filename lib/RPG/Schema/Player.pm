package RPG::Schema::Player;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Player');


__PACKAGE__->add_columns(
    'player_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'player_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'player_name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'player_name',
      'is_nullable' => 0,
      'size' => '255'
    },
    'email' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'email',
      'is_nullable' => 0,
      'size' => '255'
    },
    'password' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'password',
      'is_nullable' => 0,
      'size' => '255'
    },
);
__PACKAGE__->set_primary_key('player_id');

1;