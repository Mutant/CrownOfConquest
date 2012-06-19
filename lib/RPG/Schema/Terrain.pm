package RPG::Schema::Terrain;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Terrain');

__PACKAGE__->add_columns(qw/terrain_id terrain_name modifier image/);

__PACKAGE__->set_primary_key('terrain_id');

1;