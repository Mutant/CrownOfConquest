package RPG::Schema::Creature_Orb;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Creature_Orb');

__PACKAGE__->add_columns(qw/creature_orb_id level land_id/);

__PACKAGE__->set_primary_key(qw/creature_orb_id/);

__PACKAGE__->belongs_to(
    'land',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

1;