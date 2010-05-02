package RPG::C::Garrison;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub auto : Private {
	my ($self, $c) = @_;
	
	$c->stash->{garrison} = $c->model('DBIC::Garrison')->find(
		{
			garrison_id => $c->req->param('garrison_id'),
			party_id => $c->stash->{party}->id,
		},
		{
			prefetch => ['characters', 'land'],
		}
	);
	
	return 1;	
}

sub create : Local {
	my ($self, $c) = @_;
	
	$c->forward('RPG::V::TT',
        [{
            template => 'garrison/create.html',
            params => {
            	flee_threshold => 70, # default
            	party => $c->stash->{party},
            },
        }]
    );			
}

sub add : Local {
	my ($self, $c) = @_;
	
	if ( $c->stash->{party}->level < $c->config->{minimum_garrison_level} ) {
		$c->stash->{error} = "You can't create a garrison - your party level is too low";
		return;
	}
	
	croak "Illegal garrison creation - garrison not allowed here" unless $c->stash->{party_location}->garrison_allowed;

	my @char_ids_to_garrison = $c->req->param('chars_in_garrison');
		
	croak "Must have at least one char in the garrison" unless @char_ids_to_garrison;
	
	my @characters = $c->stash->{party}->characters;
	
	if (scalar @char_ids_to_garrison == scalar @characters) {
		croak "Must keep at least one character in the party";
	} 
	
	my $garrison = $c->model('DBIC::Garrison')->create(
		{
			land_id => $c->stash->{party_location}->land_id,
			party_id => $c->stash->{party}->id,
			creature_attack_mode => 'Attack Weaker Opponents',
			party_attack_mode => 'Densive Only',
		}
	);
	
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
	
	$c->res->redirect( $c->config->{url_root} . 'garrison/manage?garrison_id=' . $garrison->id );
}

sub update : Local {
	my ($self, $c) = @_;
	
	croak "Can't find garrison" unless $c->stash->{garrison};
	
	croak "Must be in correct sector to update garrison" unless $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;
	
	my @current_chars = $c->stash->{garrison}->characters;
		
	my %char_ids_to_garrison = map { $_ => 1 } $c->req->param('chars_in_garrison');
	
	croak "Must have at least one char in the garrison" unless %char_ids_to_garrison;
	
	my @characters = $c->stash->{party}->characters;
	if (scalar keys(%char_ids_to_garrison) - scalar @current_chars == scalar @characters) {
		croak "Must keep at least one character in the party";
	} 
	
	foreach my $current_char (@current_chars) {
		if (! $char_ids_to_garrison{$current_char->id}) {
			# Char removed
			$current_char->garrison_id(undef);
			$current_char->update;
		}
	}
	
	$c->model('DBIC::Character')->search(
		{
			character_id => [keys %char_ids_to_garrison],
			party_id => $c->stash->{party}->id,
		}
	)->update(
		{
			garrison_id => $c->stash->{garrison}->id,
		}
	);	
	
	$c->res->redirect( $c->config->{url_root} . 'garrison/manage?garrison_id=' . $c->stash->{garrison}->id );
	
}

sub remove : Local {
	my ($self, $c) = @_;
	
	confess "Can't find garrison" unless $c->stash->{garrison};
	
	foreach my $character ($c->stash->{garrison}->characters) {
		$character->garrison_id(undef);
		$character->update;	
	}
	
	$c->stash->{garrison}->delete;
	
	$c->stash->{panel_messages} = ['Garrison Removed'];
	
	$c->forward('/party/main');
}

sub manage : Local {
	my ($self, $c) = @_;
	
	confess "Can't find garrison" unless $c->stash->{garrison};
	
	my @party_garrisons = $c->stash->{party}->garrisons;
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/manage.html',
                params   => {
                    garrison => $c->stash->{garrison},
                    party_garrisons => \@party_garrisons,
                    selected => $c->req->param('selected') || '',
                },
            }
        ]
    );		
}

sub character_tab : Local {
	my ($self, $c) = @_;

	my $editable = $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/characters.html',
                params   => {
                    garrison => $c->stash->{garrison},
                    editable => $editable,
                    party => $c->stash->{party},
                },
            }
        ]
    );	
}

sub combat_log_tab : Local {
	my ($self, $c) = @_;
	
    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_garrison( $c->stash->{garrison}, 20 );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/combat_log.html',
                params   => {
                    logs  => \@logs,
                    garrison => $c->stash->{garrison},
                },
            }
        ]
    );	
}

sub orders_tab : Local {
	my ($self, $c) = @_;
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/orders.html',
                params   => {
                    garrison => $c->stash->{garrison},
                },
                fill_in_form => {$c->stash->{garrison}->get_columns},
            }
        ]
    );	
}

sub update_orders : Local {
	my ($self, $c) = @_;
	
	$c->stash->{garrison}->creature_attack_mode($c->req->param('creature_attack_mode'));
	$c->stash->{garrison}->party_attack_mode($c->req->param('party_attack_mode'));
	$c->stash->{garrison}->flee_threshold($c->req->param('flee_threshold'));
	$c->stash->{garrison}->update;
	
	$c->res->redirect( $c->config->{url_root} . 'garrison/manage?garrison_id=' . $c->stash->{garrison}->id . '&selected=orders' );
}

1;