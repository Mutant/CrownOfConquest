package RPG::C::Dungeon::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use List::Util qw(shuffle);

use RPG::Combat::CreatureDungeonBattle;

sub check_for_attack : Local {
    my ( $self, $c, $current_location ) = @_;

    # See if party is in same location as a creature
    my $creature_group = $current_location->available_creature_group;

    # If there are creatures here, check to see if we go straight into combat
    if ( $creature_group && $creature_group->number_alive > 0 ) {
        $c->stash->{creature_group} = $creature_group;

        if ( $creature_group->initiate_combat( $c->stash->{party} ) ) {
            $c->stash->{party}->in_combat_with( $creature_group->id );
            $c->stash->{party}->update;
            $c->stash->{creatures_initiated} = 1;
            
            $c->stash->{factor_comparison} = $creature_group->compare_to_party( $c->stash->{party} );

            return $creature_group;
        }
    }
}

sub party_attacks : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, } );

    my $creature_group = $current_location->available_creature_group;

    push @{ $c->stash->{refresh_panels} }, 'map';

    $c->forward( '/combat/execute_attack', [$creature_group] );
}

sub fight : Local {
    my ( $self, $c ) = @_;

    $c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        creature_group      => $c->stash->{creature_group},
        party               => $c->stash->{party},
        schema              => $c->model('DBIC')->schema,
        config              => $c->config,
        creatures_initiated => $c->stash->{creatures_initiated},
        log                 => $c->log,
    );

    my $result = $battle->execute_round;

    $c->forward( '/combat/process_round_result', [$result] );

}

sub flee : Local {
    my ( $self, $c ) = @_;

    $c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        creature_group     => $c->stash->{creature_group},
        party              => $c->stash->{party},
        schema             => $c->model('DBIC')->schema,
        config             => $c->config,
        log                => $c->log,
        party_flee_attempt => 1,
    );

    my $result = $battle->execute_round;

    $c->forward( '/combat/process_flee_result', [$result] );
}

1;
