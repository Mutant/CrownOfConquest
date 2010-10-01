package RPG::C::Town::Election;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub default : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party_location}->town;
	
	my $election = $town->current_election;
	
	croak "No current election\n" unless $election;

	my @candidates = $election->candidates; 
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/election.html',
				params        => { 
					election => $election,
					candidates => \@candidates,
					town => $town,
					tab => $c->flash->{tab},
				},
			}
		]
	);	
}

sub campaign : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party_location}->town;
	
	my $candidate = $c->model('DBIC::Character')->find(
		{
			'election.town_id' => $town->id,
			'party_id' => $c->stash->{party}->id,
		},
		{
			join => {'mayoral_candidacy' => 'election'},
		}
	);
	
	# If they don't have a candidate already, see if they have any chars that qualify
	my @allowed_candidates;	
	unless ($candidate) {
		foreach my $character ($c->stash->{party}->members) {
			if ($character->level >= $c->config->{min_character_mayoral_candidate_level} && ! $character->mayoral_candidacy) {
				push @allowed_candidates, $character;	
			};
		}
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/election/campaign.html',
				params        => { 
					candidate => $candidate,
					town => $town,
					allowed_candidates => \@allowed_candidates,
				},
			}
		]
	);		
}

sub create_candidate : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party_location}->town;
	my $election = $town->current_election;
	
	croak "No current election" unless $election;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	croak "Invalid character" if ! $character || ! $character->is_in_party || $character->mayoral_candidacy;
	
	$c->model('DBIC::Election_Candidate')->create(
		{
			character_id => $character->id,
			election_id => $election->id,
		},
	);
	
	$c->flash->{tab} = 'campaign';
	
	$c->res->redirect( $c->config->{url_root} . '/town/election' );	
}

1;