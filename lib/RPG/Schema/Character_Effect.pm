package RPG::Schema::Character_Effect;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Character_Effect');

__PACKAGE__->add_columns(qw/effect_id character_id/);

__PACKAGE__->set_primary_key(qw/effect_id character_id/);

__PACKAGE__->belongs_to(
    'character',
    'RPG::Schema::Character',
    { 'foreign.character_id' => 'self.character_id' }
);

__PACKAGE__->belongs_to(
    'effect',
    'RPG::Schema::Effect',
    { 'foreign.effect_id' => 'self.effect_id' }
);

1;