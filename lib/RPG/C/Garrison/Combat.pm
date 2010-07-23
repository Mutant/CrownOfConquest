package RPG::C::Garrison::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use RPG::Combat::GarrisonPartyBattle;

use Carp;

sub attack : Local {
	my ( $self, $c ) = @_;

	my $garrison = $c->stash->{party_location}->garrison;

	croak "No garrison here" unless $garrison;

	croak "Can't attack your own garrison" if $garrison->party_id == $c->stash->{party}->id;

	if ( $garrison->in_combat ) {
		$c->stash->{error} = "The garrison is already in combat";
	}
	elsif ( $c->stash->{party}->level - $garrison->level > $c->config->{max_party_garrison_level_difference} ) {
		$c->stash->{error} = "The garrison is too weak to attack";
	}
	else {
		$c->stash->{in_combat_with_garrison} = $garrison;
		$c->stash->{party_initiated} = 1;
		$c->stash->{party}->initiate_combat($garrison);
	}

	$c->forward( '/panel/refresh', [ 'messages', 'map', 'party' ] );
}

sub main : Private {
	my ( $self, $c ) = @_;
	
	warn $c->stash->{party_location}->garrison;

	my $output = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/main.html',
				params   => {
					opposing_garrison => $c->stash->{party_location}->garrison,
					combat_messages   => $c->stash->{combat_messages},
				},
				return_output => 1,
			},
		]
	);
	
	return $output;
}

sub fight : Local {
	my ( $self, $c ) = @_;

	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		party                   => $c->stash->{party},
		garrison                => $c->stash->{party_location}->garrison,
		schema                  => $c->model('DBIC')->schema,
		config                  => $c->config,
		log                     => $c->log,
		initiated_by_opp_number => $c->stash->{party_initiated},
	);

	my $result = $battle->execute_round;

	$c->forward( '/combat/process_round_result', [$result] );
}

sub flee : Local {
	my ( $self, $c ) = @_;

	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		party              => $c->stash->{party},
		garrison           => $c->stash->{party_location}->garrison,
		schema             => $c->model('DBIC')->schema,
		config             => $c->config,
		log                => $c->log,
		party_flee_attempt => 1,
	);

	my $result = $battle->execute_round;

	$c->forward( '/combat/process_flee_result', [$result] );
}

1;
