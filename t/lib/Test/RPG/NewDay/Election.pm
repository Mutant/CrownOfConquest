use strict;
use warnings;

package Test::RPG::NewDay::Election;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Election;
use Test::RPG::Builder::Party;

use RPG::NewDay::Action::Election;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;

    $self->{action} = RPG::NewDay::Action::Election->new( context => $self->{mock_context} );
}

sub test_run_election_mayor_retains_office : Tests(7) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, mayor_rating => 10 );
    my $election = Test::RPG::Builder::Election->build_election( $self->{schema}, town_id => $town->id, candidate_count => 2, scheduled_day => 100 );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, gold => 100 );
    my ($mayor) = $party1->characters;
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $candidate1 = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id    => $election->id,
            character_id   => $mayor->id,
            campaign_spend => 1000,
        }
    );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, gold => 100 );
    my ($char) = $party2->characters;

    my $candidate2 = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id    => $election->id,
            character_id   => $char->id,
            campaign_spend => 10,
        }
    );

    # WHEN
    $self->{action}->run_election($election);

    # THEN
    $mayor->discard_changes;
    is( $mayor->mayor_of, $town->id, "Mayor still mayor" );

    $town->discard_changes;
    is( $town->mayor_rating,   20,  "Mayor rating increased" );
    is( $town->last_election,  100, "Last election day recorded in town" );
    is( $town->history->count, 1,   "Message added to town history" );

    $election->discard_changes;
    is( $election->status, 'Closed', 'Election marked as closed' );

    is( $party1->messages->count, 1, "Mayor's party gets a message" );
    is( $party2->messages->count, 1, "Char's party gets a message" );
}

sub test_run_election_mayor_loses_office : Tests(11) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, mayor_rating => 10 );
    my $election = Test::RPG::Builder::Election->build_election( $self->{schema}, town_id => $town->id, candidate_count => 2, scheduled_day => 100 );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, gold => 100 );
    my ($mayor) = $party1->characters;
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $candidate1 = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id    => $election->id,
            character_id   => $mayor->id,
            campaign_spend => 10,
        }
    );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, gold => 100 );
    my ($char) = $party2->characters;

    my $candidate2 = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id    => $election->id,
            character_id   => $char->id,
            campaign_spend => 1000,
        }
    );

    # WHEN
    $self->{action}->run_election($election);

    # THEN
    $mayor->discard_changes;
    is( $mayor->mayor_of, undef, "Mayor no longer mayor" );

    $char->discard_changes;
    is( $char->mayor_of,                  $town->id, "Char is the new mayor" );
    is( defined $char->creature_group_id, 1,         "char is now in a cg" );

    $town->discard_changes;
    is( $town->mayor_rating,   0,   "Mayor rating reset" );
    is( $town->last_election,  100, "Last election day recorded in town" );
    is( $town->history->count, 1,   "Message added to town history" );

    $election->discard_changes;
    is( $election->status, 'Closed', 'Election marked as closed' );

    is( $party1->messages->count, 1, "Mayor's party gets a message" );
    is( $party2->messages->count, 1, "Char's party gets a message" );

    $party1->discard_changes;
    $party2->discard_changes;
    is( $party1->gold, 100, "Party 1's gold still the same (campaign not refunded)" );
    is( $party2->gold, 100, "Party 2's gold still the same (campaign not refunded)" );

}

1;
