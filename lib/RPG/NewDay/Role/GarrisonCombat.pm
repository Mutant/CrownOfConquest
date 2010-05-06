package RPG::NewDay::Role::GarrisonCombat;

use Moose::Role;

requires qw/context/;

sub execute_garrison_battle {
    my $self     = shift;
    my $garrison = shift;
    my $cg       = shift;
    my $creatures_initiated = shift;

    my $c      = $self->context;
    my $battle = RPG::Combat::GarrisonCreatureBattle->new(
        creature_group      => $cg,
        garrison            => $garrison,
        schema              => $c->schema,
        config              => $c->config,
        creatures_initiated => $creatures_initiated,
        log                 => $c->logger,
    );

    while (1) {
    	my $result = $battle->execute_round;

        last if $result->{combat_complete};
    }
}

1;