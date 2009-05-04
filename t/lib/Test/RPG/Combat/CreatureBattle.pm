use strict;
use warnings;

package Test::RPG::Combat::CreatureBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

use RPG::Combat::CreatureBattle;

sub test_finish : Tests(9) {
    my $self = shift;

    # GIVEN
    my @creatures;
    for ( 1 .. 5 ) {
        my $mock_creature_type = Test::MockObject->new();
        $mock_creature_type->set_always( 'level', 1 );
        my $mock_creature = Test::MockObject->new();
        $mock_creature->set_always( 'type', $mock_creature_type );
        push @creatures, $mock_creature;
    }
    my $mock_cg = Test::MockObject->new();
    $mock_cg->set_bound( 'creatures', \@creatures );
    $mock_cg->set_true('land_id');
    $mock_cg->set_true('dungeon_grid_id');
    $mock_cg->set_true('update');
    $mock_cg->set_always( 'level', 1 );
    $mock_cg->set_isa('RPG::Schema::CreatureGroup');

    my @characters;
    for ( 1 .. 5 ) {
        my $mock_character = Test::MockObject->new();
        $mock_character->set_always( 'id',             $_ );
        $mock_character->set_always( 'character_name', "char$_" );
        $mock_character->set_always( 'xp',             50 );
        $mock_character->set_true('update');
        $mock_character->mock( 'character_effects', sub { return () } );
        $mock_character->set_false('is_dead');
        push @characters, $mock_character;
    }
    my $mock_party = Test::MockObject->new();
    $mock_party->set_bound( 'characters', \@characters );
    $mock_party->set_always( 'gold', 100 );
    $mock_party->set_true('update');
    $mock_party->set_true('in_combat_with');

    my $mock_party_location = Test::MockObject->new();
    $mock_party_location->set_always( 'creature_threat', 5 );
    $mock_party_location->set_always('update');

    my $mock_combat_log = Test::MockObject->new();
    $mock_combat_log->set_true('gold_found');
    $mock_combat_log->set_true('xp_awarded');
    $mock_combat_log->set_true('encounter_ended');

    my $battle = Test::MockObject->new();
    $battle->set_always( 'creature_group', $mock_cg );
    $battle->set_always( 'party',          $mock_party );
    $battle->set_always( 'combat_log',     $mock_combat_log );
    $battle->set_always( 'distribute_xp', { 1 => 10, 2 => 10, 3 => 8, 4 => 10, 5 => 14 } );
    $battle->set_true('check_for_item_found');
    $battle->set_true('end_of_combat_cleanup');
    $battle->set_always( 'config', { xp_multiplier => 10 } );
    $battle->set_always( 'location', $mock_party_location );
    my $result = {};
    $battle->mock( 'result', sub { $result } );

    $self->mock_dice;
    $self->{roll_result} = 5;

    # WHEN
    RPG::Combat::CreatureBattle::finish( $battle, $mock_cg );

    # THEN
    is( defined $result->{awarded_xp}, 1,  "Awarded xp returned" );
    is( $result->{gold},               25, "Gold returned in result correctly" );

    my @args;

    is( $mock_party->call_pos(2), 'in_combat_with', "in_combat_with set to new value" );
    @args = $mock_party->call_args(2);
    is( $args[1], undef, "No longer in combat" );

    is( $mock_party->call_pos(4), 'gold', "Gold set to new value" );
    @args = $mock_party->call_args(4);
    is( $args[1], 125, "Gold set to correct value" );

    $mock_party->called_ok( 'update', 'Party updated' );

    is( $mock_cg->call_pos(3), 'land_id', 'Creature group land id changed' );
    is( $mock_cg->call_pos(5), 'update',  'Creature group updated' );

}

1;
