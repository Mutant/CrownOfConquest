package RPG::Schema::Treasure_Chest;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Treasure_Chest');

__PACKAGE__->add_columns(qw/treasure_chest_id dungeon_grid_id trap/);

__PACKAGE__->set_primary_key(qw/treasure_chest_id/);

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', { 'foreign.treasure_chest_id' => 'self.treasure_chest_id' } );

__PACKAGE__->belongs_to( 'dungeon_grid', 'RPG::Schema::Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

1;