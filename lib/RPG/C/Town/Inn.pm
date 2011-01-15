package RPG::C::Town::Inn;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub default : Local {
	my ($self, $c) = @_;
	
	$c->forward('character_list');
}

sub character_list : Private {
	my ($self, $c) = @_;
	
	$c->forward('/town/characterhold/character_list', ['inn']);
	
}

sub add_character : Local {
	my ($self, $c) = @_;

	$c->forward('/town/characterhold/add_character', ['inn']);
}

sub remove_character : Local {
	my ($self, $c) = @_;

	# Check if character is in an election
	my $town = $c->stash->{party_location}->town;
	my $election = $town->current_election;
	
	if ($election) {	
		my $candidacy = $c->model('DBIC::Election_Candidate')->find(
			{
				character_id => $c->req->param('character_id'),
				election_id => $election->id,
			},
		);
		
		# They're a candidate. Display a confirmation, or delete them
		#  from the election if they've confirmed.
		if ($candidacy) {
			my $character = $c->model('DBIC::Character')->find(
				{
					character_id => $c->req->param('character_id'),
				}
			);

			if ($c->req->param('confirm_candidate_removal')) {
				$candidacy->delete;
				
				$c->model('DBIC::Town_History')->create(
					{
						town_id => $town->id,
						day_id  => $c->stash->{today}->id,
				        message => $character->name . " has dropped out of the upcoming election.",
					}
			    );		
			}
			else {
				my $dialog = $c->forward(
					'RPG::V::TT',
					[
						{
							template => 'town/inn/confirm_candidate_removal.html',
							params   => {
								town => $town,
								character => $character,
							},
							return_output => 1,
						}
					]
				);
				
				$c->forward('/panel/create_submit_dialog', 
					[
						{
							content => $dialog,
							submit_url => 'town/inn/remove_character',
							dialog_title => 'Remove Character?',
						}
					],
				);
				
				$c->detach('character_list');
			}
		}
	}

	$c->forward('/town/characterhold/remove_character', ['inn']);
}

1;