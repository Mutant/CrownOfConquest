#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::Map;
use Carp;
use Games::Dice::Advanced;
use List::Util qw(shuffle);

my %direction_map = (
    'North'      => { y => -1, x => 0 },
    'South'      => { y => 1,  x => 0 },
    'West'       => { x => -1, y => 0 },
    'East'       => { x => 1,  y => 0 },
    'North West' => { y => -1, x => -1 },
    'North East' => { y => -1, x => 1 },
    'South West' => { y => 1,  x => -1 },
    'South East' => { y => 1,  x => 1 },
);

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @towns = $schema->resultset('Town')->search(
    { 'me.prosperity' => { '>=', 30 }, },
    { prefetech       => 'location', }

);

foreach my $town (@towns) {
    my @nearby_towns = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset    => $schema->resultset('Town'),
        relationship => 'location',
        base_point   => {
            x => $town->location->x,
            y => $town->location->y,
        },
        search_range        => 15,
        increment_search_by => 0,
        criteria            => { 'me.prosperity' => { '>=', 30 }, }
    );

    foreach my $nearby_town (@nearby_towns) {
        my $roll = Games::Dice::Advanced->roll('1d100');
        my $has_road = $town->has_road_to($nearby_town);
        
        warn "Considering a road between " 
            . $town->id . " (" . $town->location->x . ", " . $town->location->y . ") and "
            . $nearby_town->id . " (" . $nearby_town->location->x . ", " . $nearby_town->location->y . ")"
            . " - roll: $roll, has_road: $has_road, prosp: " . $town->prosperity . "\n";
        
        if ( $roll <= $town->prosperity && ! $has_road) {
            _build_road( $town, $nearby_town );
        }
    }
}

my $road_num = 0;

sub _build_road {
    my $town        = shift;
    my $nearby_town = shift;

    $road_num++;

    warn "Building road #$road_num\n";

    my $current_sector = $town->location;

    #warn "Dest sector: " . $nearby_town->location->x . ", " . $nearby_town->location->y;

    my @road_segments;

    while (1) {
        warn "Current sector: " . $current_sector->x . ", " . $current_sector->y;

        my $direction = RPG::Map->get_direction_to_point(
            {
                x => $current_sector->x,
                y => $current_sector->y,
            },
            {
                x => $nearby_town->location->x,
                y => $nearby_town->location->y,
            },
        );

        croak "Direction not found" unless $direction;

        warn $direction;

        my $next_sector = _get_sector_by_direction( $current_sector, $direction );

        #if ( $next_sector->terrain->modifier >= 7 ) {
        #    $next_sector = _check_for_different_sector( $current_sector, $next_sector, $direction );
        #}

        croak "No suitable next sector found\n" unless $next_sector;

        push @road_segments, $next_sector;

        if ( $next_sector->id == $nearby_town->location->id ) {
            last;
        }

        $current_sector = $next_sector;
    }

    # Iterate over roads to see if there's already roads between towns on the route
    my $count = 0;
    foreach my $road_segment (@road_segments) {
        if ( $road_segment->town && $road_segment->town->id != $town->id && $road_segment->town->id != $nearby_town->id ) {
            warn "found town on route\n";
            if ( $town->has_road_to( $road_segment->town ) ) {
                warn "found existing road between start and town on route\n";
                @road_segments = @road_segments[ $count .. $#road_segments ];
            }

            if ( $nearby_town->has_road_to( $road_segment->town ) ) {
                warn "found existing road between town on route and end\n";
                @road_segments = @road_segments[ 0 .. $#road_segments ];
            }
        }
        $count++;
    }

    my $last_sector = $town->location;
    foreach my $next_sector (@road_segments) {
        _join_sectors_with_road( $last_sector, $next_sector );
        _join_sectors_with_road( $next_sector, $last_sector );
        $last_sector = $next_sector;
    }
    
    _join_sectors_with_road( $last_sector, $nearby_town->location );

}

sub _join_sectors_with_road {
    my $sector1 = shift;
    my $sector2 = shift;

    return if $sector1->town;

    my $direction = RPG::Map->get_direction_to_point(
        {
            x => $sector1->x,
            y => $sector1->y,
        },
        {
            x => $sector2->x,
            y => $sector2->y,
        },
    );

    my %road_direction_map = (
        'North'      => 'top',
        'South'      => 'bottom',
        'West'       => 'left',
        'East'       => 'right',
        'North West' => 'top left',
        'North East' => 'top right',
        'South West' => 'bottom left',
        'South East' => 'bottom right',
    );

    $sector1->add_to_roads( { position => $road_direction_map{$direction}, } );

}

sub _check_for_different_sector {
    my $current_sector = shift;
    my $next_sector    = shift;
    my $direction      = shift;

    my %alt_sector = (
        'North'      => [ 'North West', 'North East' ],
        'South'      => [ 'South West', 'South East' ],
        'West'       => [ 'North West', 'South West' ],
        'East'       => [ 'North East', 'South East' ],
        'North West' => [ 'West',       'North' ],
        'North East' => [ 'East',       'North' ],
        'South West' => [ 'South',      'West' ],
        'South East' => [ 'South',      'East' ],
    );

    my $alt_direction1 = $alt_sector{$direction}->[0];
    my $alt_sector1 = _get_sector_by_direction( $current_sector, $alt_direction1 );

    my $alt_direction2 = $alt_sector{$direction}->[1];
    my $alt_sector2 = _get_sector_by_direction( $current_sector, $alt_direction2 );

    my @possible_sectors;
    if ( ref $alt_sector1 && $alt_sector1->terrain->modifier < $next_sector->terrain->modifier ) {
        push @possible_sectors, $alt_sector1;
    }

    if ( ref $alt_sector2 && $alt_sector2->terrain->modifier < $next_sector->terrain->modifier ) {
        push @possible_sectors, $alt_sector2;
    }

    if (@possible_sectors) {
        return ( shuffle @possible_sectors )[0];
    }
    else {
        return $next_sector;
    }

}

sub _get_sector_by_direction {
    my $current_sector = shift;
    my $direction      = shift;

    my $modifiers = $direction_map{$direction};

    my $next_sector_x = $current_sector->x + $modifiers->{x};
    my $next_sector_y = $current_sector->y + $modifiers->{y};

    my $next_sector = $schema->resultset('Land')->find(
        {
            x => $next_sector_x,
            y => $next_sector_y,
        },
        { 
            prefetch => ['terrain', 'town'], 
        },
    );

    warn "Couldn't find sector at $next_sector_x, $next_sector_y\n" unless $next_sector;
}
