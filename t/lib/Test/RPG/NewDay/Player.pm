use strict;
use warnings;

package Test::RPG::NewDay::Player;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Player;
use Test::RPG::Builder::Party;

use DateTime;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Player';

    $self->setup_context;
}

sub test_refer_a_friend_rewards : Tests(6) {
    my $self = shift;

    # GIVEN
    my $player1 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 'player1' );
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player1->id );

    my $player2 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 'player2', referred_by => $player1->id );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player2->id, turns_used => 1000 );

    my $player3 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 'player3', referred_by => $player1->id );
    my $party3 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player3->id, turns_used => 500 );

    my $player4 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 'player4', referred_by => $player1->id );
    my $party4_1 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player4->id, turns_used => 600 );
    my $party4_2 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player4->id, turns_used => 400, defunct => DateTime->now() );

    my $player5 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 'player5', referred_by => $player1->id, refer_reward_given => 1 );
    my $party5 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player5->id, turns_used => 1000 );

    my $action = RPG::NewDay::Action::Player->new( context => $self->{mock_context}, );

    $self->{config}->{referring_player_turn_threshold} = 1000;
    $self->{config}->{refer_a_friend_turn_reward}      = 250;

    # WHEN
    $action->refer_a_friend_rewards();

    # THEN
    $party1->discard_changes;
    is( $party1->turns,           600, "Referring party's turns increased" );
    is( $party1->messages->count, 2,   "Messages left for referring party" );

    $player2->discard_changes;
    is( $player2->refer_reward_given, 1, "Player 2 marked as refer reward given" );

    $player3->discard_changes;
    is( $player3->refer_reward_given, 0, "Player 3 not marked as refer reward given" );

    $player4->discard_changes;
    is( $player4->refer_reward_given, 1, "Player 4 marked as refer reward given" );

    $player5->discard_changes;
    is( $player5->refer_reward_given, 1, "Player 5 still marked as refer reward given" );

}

1;
