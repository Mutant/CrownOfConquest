package RPG::NewDay::Role::GarrisonCombat;

use Moose::Role;

requires qw/context/;

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
	if ($opponent->group_type eq 'creature_group') {
		$package = 'RPG::Combat::GarrisonCreatureBattle';
		$params{creature_group} = $opponent;
		$params{creatures_initiated} = $opp_initiated;
	}
	elsif ($opponent->group_type eq 'party') {
		$package = 'RPG::Combat::GarrisonPartyBattle';
		$params{party} = $opponent;
		$params{initiated_by_opp_number} = $opp_initiated ? 1 : 2;
	}

	my $battle = $package->new(
		%params
	);

	while (1) {
		my $result = $battle->execute_round;

		last if $result->{combat_complete};
	}
}

1;
