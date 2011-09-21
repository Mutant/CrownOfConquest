use strict;
use warnings;

package Test::RPG::NewDay::Turns;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Party;

use RPG::NewDay::Action::Turns;

use Test::More;
use DateTime;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;  
    
    $self->{action} = RPG::NewDay::Action::Turns->new( context => $self->{mock_context} );
}

sub test_parties_given_turns : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, turns => 100);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, turns => 90);
    my $party3 = Test::RPG::Builder::Party->build_party($self->{schema}, turns => 90, defunct => DateTime->now());
    
    $self->{config}{turns_per_hour} = 10;
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    $party1->discard_changes;
    is($party1->turns, 110, "Party 1 turns increased");
    $party2->discard_changes;
    is($party2->turns, 100, "Party 2 turns increased");
    $party3->discard_changes;
    is($party3->turns, 90,  "Party 3 turns not increased, as party is defunct");
}

1;