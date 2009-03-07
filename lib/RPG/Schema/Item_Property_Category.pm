package RPG::Schema::Item_Property_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Property_Category');

__PACKAGE__->add_columns(qw/property_category_id category_name/);
__PACKAGE__->set_primary_key('property_category_id');

1;