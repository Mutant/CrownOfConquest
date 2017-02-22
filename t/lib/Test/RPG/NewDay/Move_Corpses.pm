use strict;
use warnings;

package Test::RPG::NewDay::Move_Corpses;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use RPG::NewDay::Action::Move_Corpses;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Land;

use Test::More;

sub startup : Test(startup) {
    my $self = shift;

    $self->mock_dice;
}

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;

    $self->{action} = RPG::NewDay::Action::Move_Corpses->new( context => $self->{mock_context} );
}

sub test_move_corpse : Tests(4) {
    my $self = shift;

    # GIVEN
    my @land  = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->status('corpse');
    $character->status_context( $land[8]->id );
    $character->update;

    $self->{roll_result} = 5;

    # WHEN
    $self->{action}->run();

    # THEN
    $character->discard_changes;
    is( $character->status, 'morgue', "Character now in the morgue" );
    is( $character->status_context, $town->id, "Character in morgue of correct town" );

    my @messages = $party->messages;
    is( scalar @messages, 1, "One party message created" );
    is( $messages[0]->message, "test corpse was collected by the healer of Test Town, and interred in the town's morgue", "Correct party message text" );

}

1;
