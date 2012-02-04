package RPG::Schema::Building_Upgrade;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Building_Upgrade');

__PACKAGE__->add_columns(qw/upgrade_id building_id type_id level/);

__PACKAGE__->numeric_columns(qw/level/);

__PACKAGE__->set_primary_key(qw/upgrade_id/);

__PACKAGE__->belongs_to( 'type', 'RPG::Schema::Building_Upgrade_Type', 'type_id' );
__PACKAGE__->belongs_to( 'building', 'RPG::Schema::Building', 'building_id' );

1;
