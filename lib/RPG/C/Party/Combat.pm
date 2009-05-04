package RPG::C::Party::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use RPG::Combat::PartyWildernessBattle;

sub attack : Local {
    my ( $self, $c ) = @_;

    # TODO: validate party being attacked

    my $battle = $c->model('DBIC::Party_Battle')->create( {} );

    $battle->add_to_participants( { party_id => $c->stash->{party}->id, } );

    $battle->add_to_participants( { party_id => $c->req->param('party_id'), } );

    $c->forward( '/panel/refresh', [ 'messages', 'map', 'party' ] );
}

sub main : Private {
    my ( $self, $c ) = @_;

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'combat/main.html',
                params   => {
                    opposing_party  => $c->stash->{party}->in_party_battle_with,
                    combat_messages => $c->stash->{combat_messages},
                },
                return_output => 1,
            },
        ]
    );
}

sub fight : Local {
    my ( $self, $c ) = @_;

    my ( $party_battle, $party1, $party2 ) = _get_participants($c);

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        party_1       => $party1,
        party_2       => $party2,
        schema        => $c->model('DBIC')->schema,
        config        => $c->config,
        log           => $c->log,
        battle_record => $party_battle,
    );

    my $result = $battle->execute_round;

    $c->forward( '/combat/process_round_result', [$result] );
}

sub flee : Local {
    my ( $self, $c ) = @_;

    my ( $party_battle, $party1, $party2, $active_participant ) = _get_participants($c);

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        party_1              => $party1,
        party_2              => $party2,
        schema               => $c->model('DBIC')->schema,
        config               => $c->config,
        log                  => $c->log,
        battle_record        => $party_battle,
        party_1_flee_attempt => $active_participant == 1 ? 1 : 0,
        party_2_flee_attempt => $active_participant == 2 ? 1 : 0,
    );

    my $result = $battle->execute_round;

    $c->forward( '/combat/process_flee_result', [$result] );
}

sub _get_participants {
    my $c = shift;

    my $party_battle = $c->model('DBIC::Party_Battle')->find(
        {
            complete                => undef,
            'participants.party_id' => $c->stash->{party}->id,
        },
        { join => 'participants', }
    );

    my ( $party1, $party2 ) = $party_battle->participants;

    # Pass in the stash version of the party so we know about any changes to it
    my $active_participant;
    if ( $c->stash->{party}->id == $party1->id ) {
        $party1             = $c->stash->{party};
        $party2             = $party2->party;
        $active_participant = 1;
    }
    else {
        $party2             = $c->stash->{party};
        $party1             = $party1->party;
        $active_participant = 2;
    }

    return ( $party_battle, $party1, $party2, $active_participant );
}

1;
