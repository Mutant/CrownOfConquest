package Test::RPG::Schema::Election;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Data::Dumper;
use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Election;

sub test_cancel : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    my $election = Test::RPG::Builder::Election->build_election($self->{schema}, town_id => $town->id, candidate_count => 2);

    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, gold => 100);    
    my ($char) = $party->characters;
    
    my $candidate = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id => $election->id,
            character_id => $char->id,
            campaign_spend => 1000,
        }
    );
    
    # WHEN
    $election->cancel;
    
    # THEN
    $election->discard_changes;
    is($election->status, 'Cancelled', "Election status updated");
    
    $party->discard_changes;
    is($party->gold, 1100, "Campaign spend returned to party");
    is($party->messages->count, 1, "Message added to party");
    
}

sub test_get_scores : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, mayor_rating => 10);
    my $election = Test::RPG::Builder::Election->build_election($self->{schema}, town_id => $town->id, candidate_count => 2);
    
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, gold => 100);    
    my ($mayor) = $party1->characters;
    $mayor->mayor_of($town->id);
    $mayor->update;
    
    my $candidate1 = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id => $election->id,
            character_id => $mayor->id,
            campaign_spend => 10,
        }
    );     
    
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, gold => 100);    
    my ($char) = $party2->characters;
    
    my $candidate2 = $self->{schema}->resultset('Election_Candidate')->create(
        {
            election_id => $election->id,
            character_id => $char->id,
            campaign_spend => 1000,
        }
    );    
    
    # WHEN
    my %scores = $election->get_scores();
    
    # THEN
    is(scalar keys %scores, 4, "Scores returned for all characters");
    
    is($scores{$mayor->id}->{spend}, 0.5, "Mayor's spend returned in scores");
    is($scores{$mayor->id}->{rating}, 10, "Mayor's rating returned in scores");

    is($scores{$char->id}->{spend}, 50, "Char's spend returned in scores");
    is($scores{$char->id}->{rating}, 0, "Char's rating returned in scores");
    
}

1;