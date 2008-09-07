package RPG::Schema::Combat_Log;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Combat_Log');

__PACKAGE__->add_columns(qw/combat_log_id combat_initiated_by rounds creature_deaths character_deaths total_creature_damage
					       total_character_damage xp_awarded spells_cast gold_found outcome party_id creature_group_id land_id
					       party_level creature_group_level/);

__PACKAGE__->add_columns(
	encounter_started => { data_type => 'datetime' },
	encounter_ended   => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key('combat_log_id');

1;