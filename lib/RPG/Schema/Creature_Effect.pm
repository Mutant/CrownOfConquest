package RPG::Schema::Creature_Effect;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Creature_Effect');

__PACKAGE__->add_columns(qw/effect_id creature_id/);

__PACKAGE__->set_primary_key(qw/effect_id creature_id/);

__PACKAGE__->belongs_to(
    'creature',
    'RPG::Schema::Creature',
    { 'foreign.creature_id' => 'self.creature_id' }
);

__PACKAGE__->belongs_to(
    'effect',
    'RPG::Schema::Effect',
    { 'foreign.effect_id' => 'self.effect_id' }
);

1;
