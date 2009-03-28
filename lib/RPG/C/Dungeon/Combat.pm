package RPG::C::Dungeon::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use List::Util qw(shuffle);

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->forward('/combat/auto');
}

sub end : Private {
    my ( $self, $c ) = @_;

    $c->forward('/combat/end');
}

sub check_for_attack : Local {
    my ( $self, $c, $current_location ) = @_;
    
    # See if party is in same location as a creature
    my $creature_group = $current_location->available_creature_group;

    # If there are creatures here, check to see if we go straight into combat
    if ( $creature_group && $creature_group->number_alive > 0 ) {
        $c->stash->{creature_group} = $creature_group;

        if ( $creature_group->initiate_combat( $c->stash->{party} ) ) {
            $c->stash->{party}->in_combat_with( $creature_group->id );
            $c->stash->{party}->update;
            $c->stash->{creatures_initiated} = 1;

            $c->forward( '/combat/create_combat_log', [ $creature_group, 'creatures' ] );

            return $creature_group;
        }
    }
}

sub party_attacks : Local {
    my ($self, $c) = @_;
    
    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, } );
    
    my $creature_group = $current_location->available_creature_group;
    
    $c->forward('/combat/execute_attack', [$creature_group]);
}

sub fight : Local {
    my ( $self, $c ) = @_;
 
    $c->stash->{creature_group} = $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );
 
    if ($c->forward('/combat/check_for_creature_flee')) {
        $c->detach('creatures_flee');
    }
      
    $c->forward('/combat/execute_round');
    
}

sub flee : Local {
    my ( $self, $c ) = @_;

    my $party = $c->stash->{party};

    return unless $party->in_combat_with;

    my $flee_successful = $c->forward('/combat/roll_flee_attempt');
    
    if ($flee_successful) {
        my $new_sector = $c->forward('get_sector_to_flee_to');
        
        $party->dungeon_grid_id( $new_sector->id );
        $party->in_combat_with(undef);

        # Still costs them turns to move (but they can do it even if they don't have enough turns left)
        $party->turns( $c->stash->{party}->turns - 1 );
        $party->turns(0) if $party->turns < 0;

        $party->update;

        # Refresh stash
        $c->stash->{party}          = $party;

        $c->stash->{messages} = "You got away!";

        $c->stash->{combat_log}->outcome('party_fled');
        $c->stash->{combat_log}->encounter_ended( DateTime->now() );

        $c->forward('/combat/end_of_combat_cleanup');

        $c->forward( '/panel/refresh', [ 'messages', 'map', 'party', 'party_status' ] );
    }
    else {
        push @{ $c->stash->{combat_messages} }, 'You were unable to flee.';
        $c->session->{unsuccessful_flee_attempts}++;
        $c->forward('fight');
    }    
    
}

sub creatures_flee : Private {
    my ( $self, $c ) = @_;

    my $sector = $c->forward( 'get_sector_to_flee_to', [1] );

    $c->stash->{creature_group}->dungeon_grid_id( $sector->id );
    $c->stash->{creature_group}->update;
    undef $c->stash->{creature_group};

    $c->stash->{party}->in_combat_with(undef);
    $c->stash->{party}->update;

    $c->stash->{messages} = "The creatures have fled!";

    $c->stash->{combat_log}->outcome('creatures_fled');
    $c->stash->{combat_log}->encounter_ended( DateTime->now() );

    $c->forward('/combat/end_of_combat_cleanup');

    $c->forward( '/panel/refresh', [ 'messages', 'party', 'party_status', 'map' ] );
}

sub get_sector_to_flee_to : Private {
    my ( $self, $c, $no_creatures ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, } );

    my @sectors_to_flee_to;
    my $range = 3;
    my $max_range = 10;

    while ( !@sectors_to_flee_to ) {
        my ( $start_point, $end_point ) = RPG::Map->surrounds( $current_location->x, $current_location->y, $range, $range, );

        my %params;
        if ($no_creatures) {
            $params{'creature_group.creature_group_id'} = undef;
        }

        my @sectors_in_range = $c->model('DBIC::Dungeon_Grid')->search(
            {
                %params,
                x => { '>=', $start_point->{x}, '<=', $end_point->{x}, '!=', $current_location->x },
                y => { '>=', $start_point->{y}, '<=', $end_point->{y}, '!=', $current_location->y },
                'dungeon_room.dungeon_id' => $current_location->dungeon_room->dungeon_id, 
            },
            { join => [ 'creature_group', 'dungeon_room' ] },
        );
        
        foreach my $sector_in_range (@sectors_in_range) {
            if ($current_location->can_move_to($sector_in_range)) {
                push @sectors_to_flee_to, $sector_in_range;
            }
        }

        $range++;
        last if $range == $max_range;
    }

    @sectors_to_flee_to = shuffle @sectors_to_flee_to;
    my $land = shift @sectors_to_flee_to;

    $c->log->debug( "Fleeing to " . $land->x . ", " . $land->y );

    return $land;
}
1;