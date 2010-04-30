package RPG::C::Garrison;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub create : Local {
	my ($self, $c) = @_;
	
	my $garrison;
	my @characters;
	my $message;
	
	# Block lets use use last to exit (so we still get to the template)	
	{		
		$garrison = $c->model('DBIC::Garrison')->find(
			{
				land_id => $c->stash->{party_location}->land_id,
			}
		);
		
		if ($garrison && $garrison->party_id != $c->stash->{party}->id) {
			$c->stash->{error} = "There's already a garrison here, owned by another party!";
			last;
		} 
			
		if ($c->req->param('submit')) {
			my @char_ids_in_party = $c->req->param('in_party');
			unless (@char_ids_in_party) {
				$c->stash->{error} = "You must leave at least one character in your party";
				last;
			}
			
			my @char_ids_to_garrison = $c->req->param('in_garrison');			
					
			if ($garrison) {
				if (! @char_ids_to_garrison) {
					# No more chars, so delete the garrison
					$garrison->delete;
					$message = 'No characters are left in the garrison - garrison removed'; 
				}
				else {
					$garrison->party_attack_mode($c->req->param('party_attack_mode'));
					$garrison->creature_attack_mode($c->req->param('creature_attack_mode'));
					$garrison->flee_threshold($c->req->param('flee_threshold'));
					$garrison->update;
					$message = 'Garrison updated';
				}
			}
			else {
				if ( $c->stash->{party}->level < $c->config->{minimum_garrison_level} ) {
					$c->stash->{error} = "You can't create a garrison here - your party level is too low";
					last;
				}
				
				croak "Illegal garrison creation - garrison not allowed here" unless $c->stash->{party_location}->garrison_allowed;
				
				$garrison = $c->model('DBIC::Garrison')->create(
					{
						land_id => $c->stash->{party_location}->land_id,
						party_id => $c->stash->{party}->id,
						party_attack_mode => $c->req->param('party_attack_mode'),
						creature_attack_mode => $c->req->param('creature_attack_mode'),
						flee_threshold => $c->req->param('flee_threshold'),
					}
				);
				
				$message = 'Garrison created';
			}
				
			
			if (@char_ids_to_garrison) {
				$c->model('DBIC::Character')->search(
					{
						character_id => \@char_ids_to_garrison,
						party_id => $c->stash->{party}->id,
					}
				)->update(
					{
						garrison_id => $garrison->id,
					}
				);				
			}
			
			my $character_rs = $c->model('DBIC::Character')->search(
				{
					character_id => \@char_ids_in_party,
					party_id => $c->stash->{party}->id,
				}
			);
			
			$character_rs->update(
				{
					garrison_id => undef,
				}
			);
			
			@characters = $character_rs->all;
		}
		else {
			@characters = $c->stash->{party}->characters;
		}
	}
	
	$c->forward('RPG::V::TT',
        [{
            template => 'garrison/create.html',
            params => {
            	characters => \@characters,
            	garrison => $garrison,
            	message => $message,
            	flee_threshold => 70, # default
            },
            fill_in_form => $garrison ? {$garrison->get_columns} : 1,
        }]
    );			
}

sub combat_log : Local {
	my ($self, $c) = @_;
	
	my $garrison = $c->model('DBIC::Garrison')->find(
		{
			garrison_id => $c->req->param('garrison_id'),
			party_id => $c->stash->{party}->id,
		},
	);
	
	die "Can't find garrison" unless defined $garrison;
	
    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_garrison( $garrison, 20 );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/combat_log.html',
                params   => {
                    logs  => \@logs,
                    garrison => $garrison,
                },
            }
        ]
    );	
	
}

1;