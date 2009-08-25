package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;

use RPG::Schema::Land;
use RPG::Map;

use DBIx::Class::ResultClass::HashRefInflator;

sub view : Private {
    my ( $self, $c ) = @_;

    my $party_location = $c->stash->{party_location};
    
    my $zoom_level = $c->session->{zoom_level} || 2;
    
    my $grid_size = $c->config->{map_x_size} + (($zoom_level-2) * 3) + 1;
    $grid_size-- if $c->session->{zoom_level} % 2 == 0;    # Odd numbers cause us problems
    
    my $grid_params =
        $c->forward( 'generate_grid', [ $grid_size, $grid_size, $party_location->x, $party_location->y, 1, ], );

    $grid_params->{click_to_move} = 1;
    $grid_params->{x_size}        = $c->config->{map_x_size};
    $grid_params->{y_size}        = $c->config->{map_y_size};
    $grid_params->{grid_size}     = $c->config->{map_x_size};
    $grid_params->{zoom_level}    = $zoom_level;

    $c->forward( 'render_grid', [ $grid_params, ] );
}

sub party : Local {
    my ( $self, $c ) = @_;

    my $zoom_level = $c->req->param('zoom_level') || 2;
    if ( $zoom_level < 2 || $zoom_level > 7 ) {
        $zoom_level = 2;
    }

    my ( $centre_x, $centre_y );

    if ( $c->req->param('center_x') && $c->req->param('center_y') ) {
        ( $centre_x, $centre_y ) = ( $c->req->param('center_x'), $c->req->param('center_y') );
    }
    else {
        my $party_location = $c->stash->{party_location};

        $centre_x = $party_location->x + ( $c->req->param('x_offset') || 0 );
        $centre_y = $party_location->y + ( $c->req->param('y_offset') || 0 );
    }

    my $grid_size = $zoom_level * 9 + 1;
    $grid_size-- if $zoom_level % 2 == 1;    # Odd numbers cause us problems

    my $grid_params = $c->forward( 'generate_grid', [ $grid_size, $grid_size, $centre_x, $centre_y, ], );

    $grid_params->{click_to_move} = 0;
    $grid_params->{x_size}        = $grid_size;
    $grid_params->{y_size}        = $grid_size;
    $grid_params->{zoom_level}    = $zoom_level;
    $grid_params->{grid_size}     = $grid_size;

    my $map = $c->forward( 'render_grid', [ $grid_params, ] );

    my @known_towns = $c->model('DBIC::Town')->search(
        { 'mapped_sector.party_id' => $c->stash->{party}->id, },
        {
            prefetch => { 'location' => 'mapped_sector' },
            order_by => 'town_name',
        },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'map/party.html',
                params   => {
                    map         => $map,
                    move_amount => 12,
                    known_towns => \@known_towns,
                    zoom_level  => $zoom_level,
                },
            }
        ]
    );
}

sub known_dungeons : Local {
    my ( $self, $c ) = @_;

    my $rs = $c->model('DBIC::Mapped_Sectors')->search(
        { 'party_id' => $c->stash->{party}->id, },
        {
            prefetch => { 'location' => 'dungeon' },

            #order_by => 'level, location.x, location.y',
        },
    );

    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my @known_dungeons;

    while ( my $mapped_sector = $rs->next ) {
        my $level = $mapped_sector->{phantom_dungeon} || $mapped_sector->{location}{dungeon}{level};

        if ( $level && RPG::Schema::Dungeon->party_can_enter( $level, $c->stash->{party} ) ) {

            push @known_dungeons,
                {
                level => $level,
                x     => $mapped_sector->{location}{x},
                y     => $mapped_sector->{location}{y},
                };
        }
    }

    @known_dungeons = sort { $a->{level} <=> $b->{level} || $a->{x} <=> $b->{x} || $a->{y} <=> $b->{y} } @known_dungeons;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'map/known_dungeons.html',
                params   => { known_dungeons => \@known_dungeons, },
            }
        ]
    );

}

sub generate_grid : Private {
    my ( $self, $c, $x_size, $y_size, $x_centre, $y_centre, $add_to_party_map ) = @_;

    $c->stats->profile("Entered /map/view");

    $c->stats->profile("Got party's location");

    my ( $start_point, $end_point ) = RPG::Map->surrounds( $x_centre, $y_centre, $x_size, $y_size, 1 );

    $c->stats->profile("Got start and end point");

    my $locations = $c->model('DBIC::Land')->get_party_grid(
        start_point  => $start_point,
        end_point    => $end_point,
        centre_point => {
            x => $x_centre,
            y => $y_centre,
        },
        party_id => $c->stash->{party}->id,
    );

    $c->stats->profile("Queried db for sectors");
   
    my @roads = $c->model('DBIC::Road')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        $x_size,
    );
    
    
    my $road_grid;
    foreach my $road (@roads) {
        push @{$road_grid->[ $road->{location}->{x} ][ $road->{location}->{y} ]}, $road;
    }
    
    $c->stats->profile("Queried db for roads");

    my @grid;

    my $movement_factor = $c->stash->{party}->movement_factor;

    foreach my $location (@$locations) {
        $location->{roads} = $road_grid->[ $location->{x} ][ $location->{y} ];
        
        $grid[ $location->{x} ][ $location->{y} ] = $location;

        if ($location->{next_to_centre}) {
            $location->{party_movement_factor} = RPG::Schema::Land::movement_cost( $location, $movement_factor, $location->{modifier}, $c->stash->{party}->location );
        }
        else {
            $location->{party_movement_factor} = RPG::Schema::Land->movement_cost( $movement_factor, $location->{modifier}, );
        }

        # Record sector to the party's map
        if ( $add_to_party_map && !$location->{mapped_sector_id} ) {
            $c->model('DBIC::Mapped_Sectors')->create(
                {
                    party_id => $c->stash->{party}->id,
                    land_id  => $location->{land_id},
                },
            );
        }
        elsif ( !$add_to_party_map && !$location->{mapped_sector_id} ) {
            $grid[ $location->{x} ][ $location->{y} ] = "";
        }
    }

    $c->stats->profile("Built grid");

    return {
        grid        => \@grid,
        start_point => $start_point,
        end_point   => $end_point,
    };
}

# Render a map grid
# Params in hash:
#  * grid: grid of the map sectors to render
#  * start_point: hash of x & y location for start (i.e. top left) of the map
#  * end_point: hash of x & y location for end (i.e. bottom right) of the map

sub render_grid : Private {
    my ( $self, $c, $params ) = @_;

    $params->{x_range}          = [ $params->{start_point}{x} .. $params->{end_point}{x} ];
    $params->{y_range}          = [ $params->{start_point}{y} .. $params->{end_point}{y} ];
    $params->{image_path}       = RPG->config->{map_image_path};
    $params->{current_position} = $c->stash->{party_location};
    $params->{party_in_combat}  = $c->stash->{party}->in_combat;
    $params->{min_x}            = $params->{start_point}{x};
    $params->{min_y}            = $params->{start_point}{y};
    $params->{zoom_level} ||= 2;

    # Find any towns and calculate their tax costs
    my %town_costs;
    foreach my $row ( @{ $params->{grid} } ) {
        foreach my $sector (@$row) {
            next unless $sector;
            if ( $sector->{town_id} ) {
                my $town = $c->model('DBIC::Town')->find( { town_id => $sector->{town_id} } );

                $town_costs{ $sector->{town_id} } = $town->tax_cost( $c->stash->{party} );
            }
        }
    }

    $params->{town_costs} = \%town_costs;

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'map/generate_map.html',
                params        => $params,
                return_output => 1,
            }
        ]
    );
}

=head2 move_to

Move the party to a new location

=cut

sub move_to : Local {
    my ( $self, $c ) = @_;

    my $new_land = $c->model('DBIC::Land')->find( $c->req->param('land_id'), { prefetch => [ 'terrain', 'town' ] }, );

    my $movement_factor = $c->stash->{party}->movement_factor;

    unless ($new_land) {
        $c->error('Land does not exist!');
    }

    # Check that the new location is actually next to current position.
    elsif ( !$c->stash->{party}->location->next_to($new_land) ) {
        $c->stash->{error} = 'You can only move to a location next to your current one';
    }

    # Check that the party has enough movement points
    elsif ( $c->stash->{party}->turns < $new_land->movement_cost($movement_factor, undef, $c->stash->{party}->location) ) {
        $c->stash->{error} = 'You do not have enough turns to move there';
    }

    # If there's a town, check that they've gone in via /town/enter
    elsif ( $new_land->town && !$c->stash->{entered_town} ) {
        croak 'Invalid town entrance';
    }

    else {
        $c->stash->{party}->move_to($new_land);

        $c->stash->{party}->update;

        # Fetch from the DB, since it may have changed recently
        $c->stash->{party_location} = $c->model('DBIC::Land')->find( { land_id => $c->stash->{party}->land_id, } );

        $c->stash->{party_location}->creature_threat( $c->stash->{party_location}->creature_threat - 1 );
        $c->stash->{party_location}->update;

        my $mapped_sector = $c->model('DBIC::Mapped_Sectors')->find(
            {
                party_id => $c->stash->{party}->id,
                land_id  => $new_land->id,
            }
        );
        
        if ($mapped_sector && $mapped_sector->phantom_dungeon) {
            # They know for sure if there's a dungeon here now
            $mapped_sector->update( { phantom_dungeon => 0 } );
            
            $c->stash->{had_phantom_dungeon} = 1;
        } 

        my $creature_group = $c->forward( '/combat/check_for_attack', [$new_land] );

        # If creatures attacked, refresh party panel
        if ($creature_group) {
            push @{ $c->stash->{refresh_panels} }, 'party';
        }

    }

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

1;
