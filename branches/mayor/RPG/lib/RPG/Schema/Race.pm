package RPG::Schema::Race;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Race');

__PACKAGE__->resultset_class('RPG::ResultSet::Race');

__PACKAGE__->add_columns(
    'race_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'race_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'race_name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'race_name',
      'is_nullable' => 0,
      'size' => '255'
    },
    'base_str' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'base_str',
      'is_nullable' => 0,
      'size' => '11'
    },
    'base_int' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'base_int',
      'is_nullable' => 0,
      'size' => '11'
    },
    'base_agl' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'base_agl',
      'is_nullable' => 0,
      'size' => '11'
    },
    'base_div' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'base_div',
      'is_nullable' => 0,
      'size' => '11'
    },
    'base_con' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'base_con',
      'is_nullable' => 0,
      'size' => '11'
    },
);
__PACKAGE__->set_primary_key('race_id');

1;