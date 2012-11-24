use strict;
use warnings;

package RPG::ResultSet::Combat_Log;

use base 'DBIx::Class::ResultSet';

use RPG::Map;

sub get_logs_around_sector {
    my $self = shift;
    my ( $start_x, $start_y, $x_size, $y_size, $start_day ) = @_;

    my @coords = RPG::Map->surrounds( $start_x, $start_y, $x_size, $y_size );

    return $self->search(
        {
            'land.x'   => { '>=', $coords[0]->{x}, '<=', $coords[1]->{x} },
            'land.y'   => { '>=', $coords[0]->{y}, '<=', $coords[1]->{y} },
            'day.day_number' => { '>=', $start_day },
        },
        {
            prefetch => ['land', 'day'],
            order_by => 'encounter_ended desc',
        },
    );
}

sub get_offline_log_count {
    my $self  = shift;
    my $party = shift;
    my $date_range_start = shift;
    my $party_or_garrison_only = shift // 0;
    my $land_or_dungeon_only = shift; # undef = both
    
    $date_range_start = $party->last_action unless $date_range_start;
    
    return 0 unless $date_range_start;
    
    my %params;
    if (defined $land_or_dungeon_only) {
        if ($land_or_dungeon_only eq 'land') {
            $params{dungeon_grid_id} = undef;
        }
        elsif ($land_or_dungeon_only eq 'dungeon') {
            $params{dungeon_grid_id} = {'!=', undef};
        }
    }
     
    return $self->search(
        {
            $self->_party_criteria($party, $party_or_garrison_only),
            encounter_ended => { '>', $date_range_start },
            %params,
        },
    )->count;
}

sub get_recent_battle_count_for_garrison {
    my $self  = shift;
    my $garrison = shift;
    
    my $date_range_start = DateTime->now->subtract( hours => RPG::Schema->config->{garrison_recent_battle_period} );  
    
    return $self->search(
        {
            $self->_group_type_critiera($garrison, 'garrison'),
            encounter_ended => { '>', $date_range_start },
        },
    )->count;
}

# name = bad
sub get_offline_garrison_log_count {
    my $self  = shift;
    my $party = shift;
    my $date_range_start = shift;
    my $return_count = shift // 1;
    
    $date_range_start = $party->last_action unless $date_range_start;
    
    return 0 unless $date_range_start;
    
    my @garrisons = $party->garrisons;

    return unless @garrisons;

	my @garrions_counts;
	foreach my $garrison (@garrisons) {		
	    my $rs = $self->search(
	        {
	            $self->_group_type_critiera($garrison),
	            encounter_ended => { '>=', $date_range_start },
	        },
	    );
	    
	    my %data = (
	    	garrison => $garrison,
	    );
	    
	    if ($return_count) {
	    	my $count = $rs->count;
	    	next if $count <= 0;
	    	$data{combat_count} = $count;
	    }
	    else {
	    	$data{combat_logs} = [$rs->all];
	    }
	    
	    push @garrions_counts, \%data;
	}
	
	return @garrions_counts;
}

sub get_recent_logs_for_party {
    my $self  = shift;
    my $party = shift;
    my $logs_count = shift;
    
    return if $logs_count <= 0;
    
    return $self->search(
        {
            $self->_party_criteria($party),
        },
        {
            prefetch => 'day',
            order_by => 'encounter_ended desc',
            rows => $logs_count,
        }
    );
}

sub get_recent_logs_for_creature_group {
    my $self  = shift;
    my $cg = shift;
    my $logs_count = shift;
    
    return if $logs_count <= 0;
    
    return $self->search(
        {
            $self->_group_type_critiera($cg)
        },
        {
            prefetch => 'day',
            order_by => 'encounter_ended desc',
            rows => $logs_count,
        }
    );
}

sub get_party_logs_since_date {
    my $self  = shift;
    my $party = shift;
    my $date = shift;
    
    return unless $date;
        
    return $self->search(
        {
            $self->_party_criteria($party),
            encounter_started => {'>=', $date},
        },
        {
            prefetch => 'day',
            order_by => 'encounter_started desc',
        }
    );
}

sub get_last_days_logs_for_garrisons {
    my $self  = shift;
    my $party = shift;

	return $self->get_offline_garrison_log_count($party, DateTime->now->subtract( days => 1 ), 0);
}

sub get_logs_count_for_garrison {
    my $self  = shift;
    my $garrison = shift;
    
    my $rs = $self->search(
        {
            $self->_group_type_critiera($garrison, 'garrison'),
        },
        {}
    );
    
    return $rs->count;
}

sub get_recent_logs_for_garrison {
    my $self  = shift;
    my $garrison = shift;
    my $logs_count = shift;
    
    return if $logs_count <= 0;
    
    return $self->search(
        {
            $self->_group_type_critiera($garrison, 'garrison'),
        },
        {
            prefetch => 'day',
            order_by => 'encounter_ended desc',
            rows => $logs_count,
        }
    );
}

sub get_old_logs_for_group {
    my $self  = shift;
    my $group = shift;
    my $max_to_keep = shift;
    
    return if $max_to_keep <= 0;
    
    return $self->search(
        {
            $self->_group_type_critiera($group),
        },
        {
            order_by => 'encounter_ended desc',
            offset => $max_to_keep,
        }
    );
}

sub _party_criteria {
    my $self  = shift;
    my $party = shift;
    my $party_or_garrison_only = shift || 0;

	return $self->_group_type_critiera($party, 'party', $party_or_garrison_only);
}

sub _group_type_critiera {
	my $self = shift;
	my $group = shift;

	my $group_type = shift || $group->group_type;	
	
	my $party_or_garrison_only = shift || 0;
	
    return (
        -nest => [
            '-and' => {
                opponent_1_type => $group_type,
                opponent_1_id   => $group->id,
                ($party_or_garrison_only ? (opponent_2_type => ['party', 'garrison']) : ()),
            },
            '-and' => {
                opponent_2_type => $group_type,
                opponent_2_id   => $group->id,
                ($party_or_garrison_only ? (opponent_1_type => ['party', 'garrison']) : ()),
            }
        ]
    );	
}

1;
