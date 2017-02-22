package RPG::Schema::Battle_Participant;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Battle_Participant');

__PACKAGE__->add_columns(qw/party_id battle_id last_submitted_round online/);

__PACKAGE__->set_primary_key(qw/party_id battle_id/);

__PACKAGE__->belongs_to( 'battle', 'RPG::Schema::Party_Battle', { 'foreign.battle_id' => 'self.battle_id' } );

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

1;
