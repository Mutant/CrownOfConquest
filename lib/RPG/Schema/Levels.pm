package RPG::Schema::Levels;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Levels');

__PACKAGE__->add_columns(qw/level_number xp_needed/);

__PACKAGE__->set_primary_key('level_number');

1;