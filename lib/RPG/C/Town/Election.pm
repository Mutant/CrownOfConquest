package RPG::C::Town::Election;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub auto : Private {
	my ($self, $c) = @_;
	
	$c->stash->{town} = $c->stash->{party_location}->town;
	
	croak "Party not in a town" unless $c->stash->{town};
	
	$c->stash->{election} = $c->stash->{town}->current_election;
	
	croak "No election in town" unless $c->stash->{election};
}

sub default : Local {
	my ($self, $c) = @_;
	
	my @candidates = $c->stash->{election}->candidates; 
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/election.html',
				params        => { 
					election => $c->stash->{election},
					candidates => \@candidates,
					town => $c->stash->{town},
					tab => $c->flash->{tab} || '',
					error => $c->flash->{error} || '',
				},
			}
		]
	);	
}

sub campaign : Local {
	my ($self, $c) = @_;
	
	
	my $new_candidates_allowed = 1;
	if ($c->stash->{election}->scheduled_day - $c->stash->{today}->day_number <= $c->config->{min_days_for_election_candidacy}) {
		$new_candidates_allowed = 0;
	}
	
	my $candidate = $c->model('DBIC::Character')->find(
		{
			'election.town_id' => $c->stash->{town}->id,
			'party_id' => $c->stash->{party}->id,
			'election.status' => 'Open',
		},
		{
			join => {'mayoral_candidacy' => 'election'},
		}
	);
	
	my $candidacy;
	$candidacy = $c->model('DBIC::Election_Candidate')->find(
		{
			'election_id' => $c->stash->{election}->id,
			'character_id' => $candidate->character_id,
		}		
	) if $candidate;
	
	# If they don't have a candidate already, see if they have any chars that qualify
	my @allowed_candidates;	
	unless ($candidate && $new_candidates_allowed) {
		foreach my $character ($c->stash->{party}->members) {
			if ($character->level >= $c->config->{min_character_mayoral_candidate_level} && $character->is_in_party) {
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
					candidacy => $candidacy,
					town => $c->stash->{town},
					allowed_candidates => \@allowed_candidates,
					new_candidates_allowed => $new_candidates_allowed,
					party => $c->stash->{party},
				},
			}
		]
	);		
}

sub create_candidate : Local {
	my ($self, $c) = @_;

	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	croak "Invalid character" if ! $character || ! $character->is_in_party;

	$c->model('DBIC::Election_Candidate')->create(
		{
			character_id => $character->id,
			election_id => $c->stash->{election}->id,
		},
	);
	
	$character->status('inn');
	$character->status_context($c->stash->{town}->id);
	$character->update;
	
	$c->model('DBIC::Town_History')->create(
		{
			town_id => $c->stash->{town}->id,
			day_id  => $c->stash->{today}->id,
	        message => $character->name . " announces " . $character->pronoun('posessive-subjective') . " candidacy for the upcoming election",
		}
    );	
	
	$c->flash->{tab} = 'campaign';
	
	$c->res->redirect( $c->config->{url_root} . '/town/election' );	
}

sub add_to_spend : Local {
	my ($self, $c) = @_;
	
	croak "Invalid amount" if $c->req->param('campaign_spend') < 0;
	
	$c->flash->{tab} = 'campaign';
	
	if ($c->req->param('campaign_spend') > $c->stash->{party}->gold) {
		$c->flash->{error} = "You don't have enough gold to spend that much on the campaign";
			
		$c->res->redirect( $c->config->{url_root} . '/town/election' );	
		
		return;			
	}
	
	my $candidate = $c->model('DBIC::Character')->find(
		{
			'election.town_id' => $c->stash->{town}->id,
			'party_id' => $c->stash->{party}->id,
			'election.status' => 'Open',
		},
		{
			join => {'mayoral_candidacy' => 'election'},
		}
	);
	
	croak "No candidate for this election" unless $candidate;
	
	my $candidacy = $c->model('DBIC::Election_Candidate')->find(
		{
			'election_id' => $c->stash->{election}->id,
			'character_id' => $candidate->character_id,
		}		
	);
	$candidacy->increase_campaign_spend($c->req->param('campaign_spend'));
	$candidacy->update;
	
	$c->stash->{party}->decrease_gold($c->req->param('campaign_spend'));
	$c->stash->{party}->update;
	
	$c->res->redirect( $c->config->{url_root} . '/town/election' );
		
}

1;