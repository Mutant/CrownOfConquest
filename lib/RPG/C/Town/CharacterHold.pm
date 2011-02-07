package RPG::C::Town::CharacterHold;

# Private actions for dealing with a 'character hold' in a town (i.e. inn / street)

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub character_list : Private {
	my ($self, $c, $hold) = @_;
	confess "Hold not supplied" unless $hold;
	
	my $town = $c->stash->{party_location}->town;	

	my @characters = $c->model('DBIC::Character')->search(
		{
			status => $hold,
			status_context => $town->id,
		},
		{
			prefetch => 'party',
		}
	);
	
	$c->stash->{template_params} ||= {};
	
	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => "town/$hold/character_list.html",
				params        => {
					characters => \@characters,
					party => $c->stash->{party},
					town => $c->stash->{party_location}->town,
					%{ $c->stash->{template_params} },
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
	my ($self, $c, $hold) = @_;
	confess "Hold not supplied" unless $hold;

	my @characters = grep { ! $c->req->param('character_id') || $_->id != $c->req->param('character_id') } $c->stash->{party}->characters;
	@characters = grep { ! $_->is_dead } @characters;
		
	if ($c->req->param('character_id')) {
		croak "Can't empty party\n" unless @characters;
		
		my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters;
		
		croak "Invalid character\n" unless $character;
		
		croak "Character is dead\n" if $character->is_dead;
		
		$character->status($hold);
		$character->status_context($c->stash->{party_location}->town->id);
		$character->update;
		
		$c->stash->{party}->adjust_order;
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template      => "town/$hold/add_character.html",
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
	my ($self, $c, $hold) = @_;
	confess "Hold not supplied" unless $hold;
	
	croak "Party full\n" if $c->stash->{party}->is_full;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
		
	croak "Invalid character\n" unless $character;
	
	croak "Character not in $hold\n" unless $character->status eq $hold;
	
	croak "Not in town with character\n" unless $character->status_context == $c->stash->{party_location}->town->id;
	
	$character->status(undef);
	$character->status_context(undef);
	$character->update;
	
	$c->stash->{party}->adjust_order;
	
	push @{$c->stash->{refresh_panels}}, 'party';
	
	$c->forward('character_list', $hold);
}

1;