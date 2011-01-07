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
	
	my $town = $c->stash->{party_location}->town;	

	my @characters = $c->model('DBIC::Character')->search(
		{
			status => 'inn',
			status_context => $town->id,
		},
		{
			prefetch => 'party',
		}
	);
	
	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/inn/character_list.html',
				params        => {
					characters => \@characters,
					party => $c->stash->{party},
					town => $c->stash->{party_location}->town,
				},
				return_output => 1,
			}
		]
	);
	
	push @{$c->stash->{refresh_panels}}, ['messages', $panel ];

	# The empty array is needed, or catalyst passes some parms thru (since this could be a default method)
	$c->forward('/panel/refresh', []);		
	
}

sub add_character : Local {
	my ($self, $c) = @_;

	my @characters = grep { ! $c->req->param('character_id') || $_->id != $c->req->param('character_id') } $c->stash->{party}->characters;
		
	if ($c->req->param('character_id')) {
		croak "Can't empty party\n" unless @characters;
		
		my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters;
		
		croak "Invalid character\n" unless $character;
		
		$character->status('inn');
		$character->status_context($c->stash->{party_location}->town->id);
		$character->update;		
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/inn/add_character.html',
				params        => {
					party => $c->stash->{party},
					characters => \@characters,					
					town => $c->stash->{party_location}->town,
				},
			}
		]
	);
}

sub remove_character : Local {
	my ($self, $c) = @_;
	
	croak "Party full\n" if $c->stash->{party}->is_full;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
		
	croak "Invalid character\n" unless $character;
	
	croak "Character not in inn\n" unless $character->status eq 'inn';
	
	croak "Not in town with character\n" unless $character->status_context == $c->stash->{party_location}->town->id;
	
	$character->status(undef);
	$character->status_context(undef);
	$character->update;
	
	push @{$c->stash->{refresh_panels}}, 'party';
	
	$c->forward('character_list');
}

1;