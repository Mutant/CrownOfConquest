package RPG::NewDay::Role::GarrisonCombat;

use Moose::Role;

requires qw/context/;

use feature 'switch';

use RPG::Combat::GarrisonCreatureBattle;
use RPG::Combat::GarrisonPartyBattle;

sub execute_garrison_battle {
	my $self                = shift;
	my $garrison            = shift;
	my $opponent            = shift;
	my $opp_initiated = shift;

	my $c = $self->context;

	my %params = (
		garrison            => $garrison,
		schema              => $c->schema,
		config              => $c->config,
		log                 => $c->logger,
	);

	my $package;
	given ( $opponent->group_type ) {
		when ('creature') {
			$package = 'RPG::Combat::GarrisonCreatureBattle';
			$params{creature_group} = $opponent;
			$params{creatures_initiated} = $opp_initiated;
		}
		when ('party') {
			$package = 'RPG::Combat::GarrisonPartyBattle';
			$params{party} = $opponent;
			$params{initiated_by_opp_number} = $opp_initiated ? 1 : 2;
		}
	}

	my $battle = $package->new(
		%params
	);

	while (1) {
		my $result = $battle->execute_round;

		last if $result->{combat_complete};
	}
	
	if ($opponent->group_type eq 'party') {
		$opponent->end_combat;	
	}
}

sub check_for_garrison_fight {
	my $self        = shift;
	my $cg          = shift;
	my $garrison    = shift;
	my $attack_mode = shift;

	return 0 if $attack_mode eq 'Defensive Only';

	my $factor = $cg->compare_to_party($garrison);

	given ($attack_mode) {
		when ( 'Attack Weaker Opponents' && $factor > 20 ) {
			return 1;
		}
		when ( 'Attack Similar Opponents' && $factor > 5 ) {
			return 1;
		}
		when ( 'Attack Stronger Opponents' && $factor > -15 ) {
			return 1;
		}
	}

	return 0;
}

1;
