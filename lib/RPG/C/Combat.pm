package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use RPG::Combat::CreatureWildernessBattle;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use DateTime;

# Check to see if creatures attack party (if there are any in their current sector)
sub check_for_attack : Local {
    my ( $self, $c, $new_land ) = @_;

    # See if party is in same location as a creature
    my $creature_group = $new_land->available_creature_group;

    # If there are creatures here, check to see if we go straight into combat
    if ( $creature_group && $creature_group->number_alive > 0 ) {
        $c->stash->{creature_group} = $creature_group;

        if ( $creature_group->initiate_combat( $c->stash->{party} ) ) {
            $c->stash->{party}->in_combat_with( $creature_group->id );
            $c->stash->{party}->update;
            $c->stash->{creatures_initiated} = 1;

            return $creature_group;
        }
    }
}

sub party_attacks : Local {
    my ( $self, $c ) = @_;

    my $creature_group = $c->stash->{party_location}->available_creature_group;

    push @{ $c->stash->{refresh_panels} }, 'map';

    $c->forward( 'execute_attack', [$creature_group] );

}

sub execute_attack : Private {
    my ( $self, $c, $creature_group ) = @_;

    if ($creature_group) {
        $c->stash->{creature_group} = $creature_group;

        $c->stash->{party}->in_combat_with( $creature_group->id );
        $c->stash->{party}->update;

        $c->forward( '/panel/refresh', [ 'messages', 'party' ] );
    }
    else {
        $c->stash->{messages} = "The creatures have moved, or have been attacked by someone else.";
        $c->forward( '/panel/refresh', ['messages'] );
    }

}

sub main : Local {
    my ( $self, $c ) = @_;

    my $creature_group = $c->stash->{creature_group};
    unless ($creature_group) {
        $creature_group =
            $c->model('DBIC::CreatureGroup')
            ->find( { creature_group_id => $c->stash->{party}->in_combat_with, }, { prefetch => { 'creatures' => 'type' }, }, );
    }

    my $orb;
    if ( $c->stash->{creatures_initiated} && !$c->stash->{party}->dungeon_grid_id ) {
        $orb = $c->stash->{party_location}->orb;
    }

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'combat/main.html',
                params   => {
                    creature_group      => $creature_group,
                    creatures_initiated => $c->stash->{creatures_initiated},
                    combat_messages     => $c->stash->{combat_messages},
                    combat_complete     => $c->stash->{combat_complete},
                    party_dead          => $c->stash->{party}->defunct ? 1 : 0,
                    orb                 => $orb,
                    in_dungeon          => $c->stash->{party}->dungeon_grid_id ? 1 : 0,
                },
                return_output => 1,
            }
        ]
    );
}

sub select_action : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find( $c->req->param('character_id') );

    $character->last_combat_action( $c->req->param('action') );

    # Remove empty strings
    my @action_params = grep { $_ ne '' } $c->req->param('action_param');

    $character->last_combat_param1( $action_params[0] || '' );
    $character->last_combat_param2( $action_params[1] || '' );
    $character->update;
}

sub fight : Local {
    my ( $self, $c ) = @_;

    $c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );

    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        creature_group      => $c->stash->{creature_group},
        party               => $c->stash->{party},
        schema              => $c->model('DBIC')->schema,
        config              => $c->config,
        creatures_initiated => $c->stash->{creatures_initiated},
        log                 => $c->log,
        creatures_can_flee  => $c->stash->{party_location}->orb ? 0 : 1,    # Don't flee if there's an orb present
    );

    my $result = $battle->execute_round;

    $c->forward( '/combat/process_round_result', [$result] );
}

sub flee : Local {
    my ( $self, $c ) = @_;

    $c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );

    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        creature_group     => $c->stash->{creature_group},
        party              => $c->stash->{party},
        schema             => $c->model('DBIC')->schema,
        config             => $c->config,
        log                => $c->log,
        creatures_can_flee => $c->stash->{party_location}->orb ? 0 : 1,    # Don't flee if there's an orb present
        party_flee_attempt => 1,
    );

    my $result = $battle->execute_round;

    $c->forward( '/combat/process_flee_result', [$result] );

}

sub process_round_result : Private {
    my ( $self, $c, $result ) = @_;

    push @{ $c->stash->{combat_messages} },
        $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'combat/message.html',
                params   => {
                    combat_messages => $result->{messages},
                    combat_complete => $result->{combat_complete},
                },
                return_output => 1,
            }
        ]
        );

    my @panels_to_refesh = ( 'messages', 'party', 'party_status' );
    if ( $result->{combat_complete} ) {
        
        push @panels_to_refesh, 'map';
        
        if (! $c->stash->{party}->defunct) {
            my $xp_messages = $c->forward( '/party/xp_gain', [ $result->{awarded_xp} ] );
    
            push @{ $c->stash->{combat_messages} }, @$xp_messages;
    
            push @{ $c->stash->{combat_messages} }, "You find $result->{gold} gold";
    
            foreach my $item_found ( @{ $result->{found_items} } ) {
                push @{ $c->stash->{combat_messages} }, $item_found->{finder}->character_name . " found a " . $item_found->{item}->display_name;
            }
    
            # Check for state of quests
            my $messages = $c->forward( '/quest/check_action', ['creature_group_killed'] );
            push @{ $c->stash->{combat_messages} }, @$messages;
            
            push @{ $c->stash->{combat_messages} }, "The creatures have been killed";
        }
        else {
            push @{ $c->stash->{combat_messages} }, "Your party has been wiped out!";
        }

        # Force combat main to display final time
        $c->stash->{messages_path} = '/combat/main';

    }
    if ( $result->{creatures_fled} ) {
        push @panels_to_refesh, 'map';

        undef $c->stash->{creature_group};

        $c->stash->{messages} = "The creatures have fled!";
    }

    $c->stash->{combat_complete} = $result->{combat_complete};

    $c->forward( '/panel/refresh', \@panels_to_refesh );
}

sub process_flee_result : Private {
    my ( $self, $c, $result ) = @_;

    my @panels_to_refesh = ( 'messages', 'party', 'party_status' );

    if ( $result->{party_fled} ) {
        $c->stash->{messages} = "You got away!";
        $c->log->debug("discarding party");

        $c->stash->{party}->discard_changes;
        $c->stash->{party_location} = $c->stash->{party}->location;

        undef $c->stash->{creature_group};
        push @panels_to_refesh, 'map';
        
        $c->forward( '/panel/refresh', \@panels_to_refesh );
    }
    else {
        push @{ $c->stash->{combat_messages} }, "You were unable to flee";
        
        $c->forward( '/combat/process_round_result', [$result] );
    }    
}

1;
