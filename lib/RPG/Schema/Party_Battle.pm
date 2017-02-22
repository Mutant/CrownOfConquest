package RPG::Schema::Party_Battle;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Party_Battle');

__PACKAGE__->add_columns(qw/battle_id/);

__PACKAGE__->set_primary_key('battle_id');

__PACKAGE__->add_columns(
    complete => { data_type => 'datetime' },
);

__PACKAGE__->has_many(
    'participants',
    'RPG::Schema::Battle_Participant',
    { 'foreign.battle_id' => 'self.battle_id' }
);

1;
