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

    my $building = $c->stash->{party_location}->building;

	if ( $garrison->in_combat ) {
		$c->stash->{error} = "The garrison is already in combat";
	}
	elsif ( ! $building && ! $garrison->claim_land_order && 
        $c->stash->{party}->level - $garrison->level > $c->config->{max_party_garrison_level_difference} ) {
		
		$c->stash->{error} = "The garrison is too weak to attack";
	}
	elsif ( $c->model('DBIC::Combat_Log')->get_recent_battle_count_for_garrison( $garrison ) >= $c->config->{garrison_recent_battle_max} ) {
	    $c->stash->{error} = 'This garrison has been attacked too many times recently';
	}
    elsif ( $c->stash->{party}->is_suspected_of_coop_with($garrison->party) ) {
        $c->stash->{error} = 'Cannot attack this garrison as the party that owns it has IP addresses in common with your account'; 
    }
	else {
		$c->stash->{in_combat_with_garrison} = $garrison;
		$c->stash->{party_initiated} = 1;
		$c->stash->{party}->initiate_combat($garrison);
	}

	$c->forward( '/panel/refresh', [ 'messages', 'map', 'party', 'creatures' ] );
}

sub main : Private {
	my ( $self, $c ) = @_;

    $c->stash->{creature_group} = $c->stash->{party_location}->garrison;
    
    $c->stash->{message_panel_size} = 'large';
	
	my $output = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/main.html',
				params   => {
					combat_messages   => $c->stash->{combat_messages},
					garrison_initiated  => $c->stash->{garrison_initiated} ? 1 : 0,
					type => 'garrison',
				},
				return_output => 1,
			},
		]
	);
	
	return $output;
}

sub fight : Local {
	my ( $self, $c ) = @_;
	
	$c->stash->{in_combat_with_garrison} = $c->stash->{party_location}->garrison;

	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		party                   => $c->stash->{party},
		garrison                => $c->stash->{in_combat_with_garrison},
		schema                  => $c->model('DBIC')->schema,
		config                  => $c->config,
		log                     => $c->log,
		initiated_by_opp_number => $c->stash->{party_initiated} ? 1 : 2,
	);

	my $result = $battle->execute_round;

	$c->forward( '/combat/process_round_result', [$result] );
}

sub flee : Local {
	my ( $self, $c ) = @_;

	$c->stash->{in_combat_with_garrison} = $c->stash->{party_location}->garrison;

	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		party              => $c->stash->{party},
		garrison           => $c->stash->{in_combat_with_garrison},
		schema             => $c->model('DBIC')->schema,
		config             => $c->config,
		log                => $c->log,
		party_flee_attempt => 1,
	);

	my $result = $battle->execute_round;

	$c->forward( '/combat/process_flee_result', [$result] );
}

1;
