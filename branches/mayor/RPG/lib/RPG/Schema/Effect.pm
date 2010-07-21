package RPG::Schema::Effect;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Effect');

__PACKAGE__->resultset_class('RPG::ResultSet::Effect');

__PACKAGE__->add_columns(qw/effect_id effect_name time_left modifier modified_stat combat time_type/);

__PACKAGE__->set_primary_key('effect_id');

__PACKAGE__->might_have(
    'character_effect',
    'RPG::Schema::Character_Effect',
    { 'foreign.effect_id' => 'self.effect_id' }
);

__PACKAGE__->might_have(
    'creature_effect',
    'RPG::Schema::Creature_Effect',
    { 'foreign.effect_id' => 'self.effect_id' }
);

__PACKAGE__->might_have(
    'party_effect',
    'RPG::Schema::Party_Effect',
    { 'foreign.effect_id' => 'self.effect_id' }
);

1;