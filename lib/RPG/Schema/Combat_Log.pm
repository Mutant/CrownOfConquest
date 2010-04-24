package RPG::Schema::Combat_Log;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Combat_Log');

__PACKAGE__->resultset_class('RPG::ResultSet::Combat_Log');

__PACKAGE__->add_columns(
    qw/combat_log_id combat_initiated_by rounds opponent_1_deaths opponent_2_deaths total_opponent_1_damage
        total_opponent_2_damage xp_awarded spells_cast gold_found outcome land_id opponent_1_id opponent_2_id
        opponent_1_level opponent_2_level game_day opponent_1_flee_attempts opponent_2_flee_attempts 
        opponent_1_type opponent_2_type session dungeon_grid_id/
);

__PACKAGE__->add_columns(
    encounter_started => { data_type => 'datetime' },
    encounter_ended   => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key('combat_log_id');

__PACKAGE__->belongs_to( 'land', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.game_day' } );

# Note, party and creature_group relationships defined manually, as DBIx::Class doesn't support complex
#  join conditions
sub opponent_1 {
    my $self = shift;
    return $self->opponent(1);   
}

sub opponent_2 {
    my $self = shift;
    return $self->opponent(2);   
}

sub opponent_stats {
    my $self = shift;
    
    my %stats = (
        1 => {
            deaths => $self->opponent_1_deaths || 0,
            damage_inflicted => $self->total_opponent_1_damage,
            type => $self->opponent_1_type,
            level => $self->opponent_1_level,
            flee_attempts => $self->opponent_1_flee_attempts,
        },
        2 => {
            deaths => $self->opponent_2_deaths || 0,
            damage_inflicted => $self->total_opponent_2_damage,
            type => $self->opponent_2_type,
            level => $self->opponent_2_level,
            flee_attempts => $self->opponent_2_flee_attempts,
        },    
    );
    
    return \%stats;
}

sub was_initiated_by_party {
    my $self = shift;
    my $party = shift;
    
    if ($self->party_opponent_number($party) == 1 && $self->combat_initiated_by eq 'opp1') {
        return 1;   
    }
    
    if ($self->party_opponent_number($party) == 2 && $self->combat_initiated_by eq 'opp2') {
        return 1;   
    }    
    
    return 0;
}

sub party_opponent_number {
    my $self = shift;
    my $party = shift;
    
    if ($self->opponent_1_type eq 'party' && $self->opponent_1->id == $party->id) {
        return 1;   
    }
    
    return 2;     
}

sub opponent {
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
        
    return $self->{_party}{$id} if defined $self->{_party}{$id};

    my $party = $self->result_source->schema->resultset('Party')->find( { party_id => $id, }, );

    $self->{_party}{$id} = $party;

    return $party;
}

sub _get_cg {
    my $self = shift;
    my $id   = shift;
    
    return $self->{_cg}{$id} if defined $self->{_cg}{$id};

    my $cg = $self->result_source->schema->resultset('CreatureGroup')->find(
        { creature_group_id => $id, },
        {
            prefetch => { 'creatures' => 'type' },
        },
    );
    
    $self->{_cg}{$id} = $cg;

    return $cg;
}

sub location {
    my $self = shift;
    
    if ($self->land_id) {
        my $land = $self->result_source->schema->resultset('Land')->find(
            {
                land_id => $self->land_id,
            }
        );
        
        return unless $land;
        
        return "sector " . $land->x . ", " . $land->y;
    }
    else {
        my $dungeon = $self->result_source->schema->resultset('Dungeon')->find(
            {
                'sectors.dungeon_grid_id' => $self->dungeon_grid_id,
            },
            {
                join => {'rooms' => 'sectors'},  
                prefetch => 'location',
            },
        );
        
        return unless $dungeon;
        
        return "a level " . $dungeon->level . " dungeon at " . $dungeon->location->x . ", " . $dungeon->location->y;
    }   
}

sub record_damage {
	my $self = shift;
	my $opp_number = shift // croak "Opp number not supplied"; #/
	my $damage = shift // croak "Damage not supplied"; #/
	
	my $damage_col = 'total_opponent_' . $opp_number . '_damage';
    $self->set_column( $damage_col, ( $self->get_column($damage_col) || 0 ) + $damage );
}

sub record_death {
	my $self = shift;
	my $opp_number = shift // croak "Opp number not supplied"; #/
	
	my $damage_col = 'opponent_' . $opp_number . '_deaths';
    $self->set_column( $damage_col, ( $self->get_column($damage_col) || 0 ) + 1 );
}

1;
