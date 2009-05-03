package RPG::Schema::Combat_Log;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Combat_Log');

__PACKAGE__->resultset_class('RPG::ResultSet::Combat_Log');

__PACKAGE__->add_columns(
    qw/combat_log_id combat_initiated_by rounds creature_deaths character_deaths total_creature_damage
        total_character_damage xp_awarded spells_cast gold_found outcome land_id opponent_1_id opponent_2_id
        party_level creature_group_level game_day flee_attempts opponent_1_type opponent_2_type session/
);

__PACKAGE__->add_columns(
    encounter_started => { data_type => 'datetime' },
    encounter_ended   => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key('combat_log_id');

__PACKAGE__->belongs_to( 'land', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

# Note, party and creature_group relationships defined manually, as DBIx::Class doesn't support complex
#  join conditions
sub opponent_1 {
    my $self = shift;
    return $self->_opponent(1);   
}

sub opponent_2 {
    my $self = shift;
    return $self->_opponent(2);   
}


sub _opponent {
    my $self = shift;
    my $opp_number = shift;
    
    my $id = $self->get_column("opponent_${opp_number}_id");
    
    if ($self->get_column("opponent_${opp_number}_type") eq 'party') {
        return $self->_get_party($id);
    } 
    else {
        return $self->_get_cg($id);
    }

}

sub _get_party {
    my $self = shift;
    my $id   = shift;

    my $party = $self->result_source->schema->resultset('Party')->find( { party_id => $id, }, );

    return $party;
}

sub _get_cg {
    my $self = shift;
    my $id   = shift;

    my $cg = $self->result_source->schema->resultset('CreatureGroup')->find(
        { creature_group_id => $id, },
        {
            prefetch => { 'creatures' => 'type' },
        },
    );

    return $cg;
}

1;
