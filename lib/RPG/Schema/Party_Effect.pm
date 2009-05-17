package RPG::Schema::Party_Effect;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Party_Effect');

__PACKAGE__->add_columns(qw/effect_id party_id/);

__PACKAGE__->set_primary_key(qw/effect_id party_id/);

__PACKAGE__->belongs_to(
    'party',
    'RPG::Schema::Party',
    { 'foreign.party_id' => 'self.party_id' }
);

__PACKAGE__->belongs_to(
    'effect',
    'RPG::Schema::Effect',
    { 'foreign.effect_id' => 'self.effect_id' }
);

1;