package RPG::Schema::Super_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Super_Category');

__PACKAGE__->add_columns(qw/super_category_id super_category_name/);
__PACKAGE__->set_primary_key('super_category_id');

1;