package RPG::C::Party::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use RPG::Combat::PartyWildernessBattle;

use Carp;

sub attack : Local {
    my ( $self, $c ) = @_;

    my $party_attacked = $c->model('DBIC::Party')->find( $c->req->param('party_id') );

    croak "Opponent party not found" unless defined $party_attacked;

    if ($party_attacked->land_id != $c->stash->{party}->land_id) {
		c->stash->{error} = "Can't attack a party in a different sector";
    }
    elsif ($party_attacked->dungeon_grid_id) {
        $c->stash->{error} = "Can't attack a party in a dungeon";
    }
    elsif ( $party_attacked->in_combat ) {
        $c->stash->{error} = 'That party is already in combat';
    }
    elsif ( $c->stash->{party}->level - $party_attacked->level > $c->config->{max_party_level_diff_for_attack} ) {
        $c->stash->{error} = 'The party is too low level to attack';
    }
    elsif ( $c->model('DBIC::Combat_Log')->get_offline_log_count( $party_attacked, undef, 1 ) > $c->config->{max_party_offline_attacks} ) {
    	$c->stash->{error} = 'This party has been attacked too many times recently';
    }
    else {

        my $battle = $c->model('DBIC::Party_Battle')->create( {} );

        $battle->add_to_participants( { party_id => $c->stash->{party}->id, online => 1 } );

        $battle->add_to_participants( { party_id => $c->req->param('party_id'), } );
    }

    $c->forward( '/panel/refresh', [ 'messages', 'map', 'party' ] );
}

sub main : Private {
    my ( $self, $c ) = @_;

    # Check this is the online party
    my $participant = $c->model('DBIC::Battle_Participant')->find(
        {
            party_id          => $c->stash->{party}->id,
            'battle.complete' => undef,
        },
        { join => 'battle', }
    );

    unless ( $participant->online ) {
        return $c->forward(
            'RPG::V::TT',
            [
                {
                    template      => 'combat/other_party_online.html',
                    return_output => 1,
                }
            ],
        );
    }

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

    my ( $party_battle, $party1, $party2, $active_participant ) = _get_participants($c);

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        party_1                 => $party1,
        party_2                 => $party2,
        schema                  => $c->model('DBIC')->schema,
        config                  => $c->config,
        log                     => $c->log,
        battle_record           => $party_battle,
        initiated_by_opp_number => $active_participant, # Assume it's the active party who initiated (for now)
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
