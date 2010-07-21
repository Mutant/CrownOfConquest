package RPG::Schema::Dimension;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Dimension');


__PACKAGE__->add_columns(
    'group_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'group_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'group_name' => {
      'data_type' => 'char',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'group_name',
      'is_nullable' => 0,
      'size' => '255'
    },
);
__PACKAGE__->set_primary_key('group_id');

1;