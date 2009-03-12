package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

use RPG::Schema::Land;
use RPG::Map;

sub view : Local {
    my ( $self, $c ) = @_;

    my $party_location = $c->stash->{party_location};

    my $grid_params =
        $c->forward( 'generate_grid', [ $c->config->{map_x_size}, $c->config->{map_y_size}, $party_location->x, $party_location->y, 1, ], );

    $grid_params->{click_to_move} = 1;
    $grid_params->{x_size} = $c->config->{map_x_size};
    $grid_params->{y_size} = $c->config->{map_y_size};

    return $c->forward( 'render_grid', [ $grid_params, ] );
}

sub party : Local {
    my ( $self, $c ) = @_;
    
    my $zoom_level = $c->req->param('zoom_level') || 2; 

    my ( $centre_x, $centre_y );

    if ( $c->req->param('center_x') && $c->req->param('center_y') ) {
        ( $centre_x, $centre_y ) = ( $c->req->param('center_x'), $c->req->param('center_y') );
    }
    else {
        my $party_location = $c->stash->{party_location};

        $centre_x = $party_location->x + ($c->req->param('x_offset') || 0);
        $centre_y = $party_location->y + ($c->req->param('y_offset') || 0);
    }
    
    my $grid_size = $zoom_level * 10 + 1;

    my $grid_params = $c->forward( 'generate_grid', [ $grid_size, $grid_size, $centre_x, $centre_y, ], );

    $grid_params->{click_to_move} = 0;    
    $grid_params->{x_size} = $grid_size;
    $grid_params->{y_size} = $grid_size;
    $grid_params->{zoom_level} = $zoom_level;

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
                },
            }
        ]
    );
}

sub known_dungeons : Local {
    my ( $self, $c ) = @_;
    
    my @known_dungeons = $c->model('DBIC::Dungeon')->search(
        { 'mapped_sector.party_id' => $c->stash->{party}->id, },
        {
            prefetch => { 'location' => 'mapped_sector' },
            order_by => 'location.x, location.y',
        },
    );
    
    @known_dungeons = grep { $_->party_can_enter($c->stash->{party}) } @known_dungeons;
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'map/known_dungeons.html',
                params   => {
                    known_dungeons => \@known_dungeons,
                },
            }
        ]
    );    
    
}

sub generate_grid : Private {
    my ( $self, $c, $x_size, $y_size, $x_centre, $y_centre, $add_to_party_map ) = @_;

    $c->stats->profile("Entered /map/view");

    $c->stats->profile("Got party's location");

    my ( $start_point, $end_point ) = RPG::Map->surrounds( $x_centre, $y_centre, $x_size, $y_size, );

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

    my @grid;

    my $movement_factor = $c->stash->{party}->movement_factor;

    foreach my $location (@$locations) {
        $grid[ $location->{x} ][ $location->{y} ] = $location;

        $location->{party_movement_factor} = RPG::Schema::Land->movement_cost( $movement_factor, $location->{modifier}, );

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
    $params->{party_in_combat}  = $c->stash->{party}->in_combat_with;
    $params->{min_x} = $params->{start_point}{x};
    $params->{min_y} = $params->{start_point}{y};
    $params->{zoom_level} ||= 2;
    $params->{zoom_level} = 8 if $params->{zoom_level} > 8;


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

    my $new_land = $c->model('DBIC::Land')->find( $c->req->param('land_id'), { prefetch => 'terrain', }, );

    my $movement_factor = $c->stash->{party}->movement_factor;

    unless ($new_land) {
        $c->error('Land does not exist!');
    }

    # Check that the new location is actually next to current position.
    elsif ( !$c->stash->{party}->location->next_to($new_land) ) {
        $c->stash->{error} = 'You can only move to a location next to your current one';
    }

    # Check that the party has enough movement points
    elsif ( $c->stash->{party}->turns < $new_land->movement_cost($movement_factor) ) {
        $c->stash->{error} = 'You do not have enough turns to move there';
    }

    else {
        $c->stash->{party}->land_id( $c->req->param('land_id') );
        $c->stash->{party}->turns( $c->stash->{party}->turns - $new_land->movement_cost($movement_factor) );

        $c->stash->{party}->update;

        $c->stash->{party_location}->creature_threat( $c->stash->{party_location}->creature_threat - 1 );
        $c->stash->{party_location}->update;

        # Fetch from the DB, since it may have changed recently
        $c->stash->{party_location} = $c->model('DBIC::Land')->find( { land_id => $c->stash->{party}->land_id, } );

        my $creature_group = $c->forward( '/combat/check_for_attack', [$new_land] );

        # If creatures attacked, refresh party panel
        if ($creature_group) {
            push @{ $c->stash->{refresh_panels} }, 'party';
        }

    }

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

1;
