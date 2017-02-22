package RPG::Schema::Creature_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Creature_Category');

__PACKAGE__->add_columns(qw/creature_category_id name dungeon_group_img standard/);

__PACKAGE__->set_primary_key(qw/creature_category_id/);

1;
