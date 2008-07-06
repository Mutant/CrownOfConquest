package RPG::Schema::Equip_Place_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Equip_Place_Category');

__PACKAGE__->add_columns(qw/equip_place_id item_category_id/);
__PACKAGE__->set_primary_key(qw/equip_place_id item_category_id/);

__PACKAGE__->belongs_to(
    'item_category',
    'RPG::Schema::Item_Category',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);

1;