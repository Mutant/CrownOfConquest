package RPG::Schema::Town_Raid;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Town_Raid');

__PACKAGE__->add_columns(qw/raid_id town_id party_id day_id defeated_mayor detected guards_killed defences defending_party battle_count/);

__PACKAGE__->set_primary_key('raid_id');

__PACKAGE__->add_columns(
	date_started => { data_type => 'datetime' },
	date_ended   => { data_type => 'datetime' },
);

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', 'day_id' );
__PACKAGE__->belongs_to( 'town', 'RPG::Schema::Town', 'town_id' );
__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id' );
__PACKAGE__->might_have( 'defending_party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.defending_party' } );

1;