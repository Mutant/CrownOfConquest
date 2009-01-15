use strict;
use warnings;

package Test::RPG::Ticker_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;

use RPG::Ticker;

sub setup_data : Test(startup) {
    my $self = shift;

    my $logger = Test::MockObject->new();
    $logger->set_true('warn');
    $logger->set_true('info');
    $logger->set_true('debug');

    $self->{logger} = $logger;
}

sub setup : Test(setup) {
    my $self = shift;

    $self->{config} = {
        land_per_orb                   => 4,
        min_orb_distance_from_town     => 2,
        min_orb_level_cg               => 2,
        max_orb_level_cg               => 3,
        creature_groups_to_parties     => 5,
        max_creature_groups_per_sector => 1,
        min_creature_groups_per_sector => 0,
    };

    $self->{creature_type_1} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 1,
        }
    );

    $self->{creature_type_2} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 2,
        }
    );

    $self->{creature_type_3} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 3,
        }
    );
}

sub test_spawn_orbs_successful_run : Tests(7) {
    my $self = shift;

    my @land = $self->_create_land();

    # Towns on top left and bottom right corners
    $land[0]->terrain_id( $self->{town_terrain}->id );
    $land[0]->update;
    $land[8]->terrain_id( $self->{town_terrain}->id );
    $land[8]->update;

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs,                           2, "Should be two orbs" );
    is( $orbs[0]->land->x,                      1, "First orb should be at x=1" );
    is( $orbs[0]->land->y,                      3, "First orb should be at y=3" );
    is( defined $orbs[0]->land->creature_group, 1, "Creature group spawned at first orb" );

    is( $orbs[1]->land->x,                      3, "Second orb should be at x=3" );
    is( $orbs[1]->land->y,                      1, "Second orb should be at y=1" );
    is( defined $orbs[1]->land->creature_group, 1, "Creature group spawned at second orb" );

}

sub test_spawn_orb_successful_run_with_existing_orb : Test(1) {
    my $self = shift;

    my @land = $self->_create_land();

    # Towns on top left and bottom right corners
    $land[0]->terrain_id( $self->{town_terrain}->id );
    $land[0]->update;

    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[2]->id, } );

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs, 2, "Should be two orbs" );

}

sub test_spawn_orb_no_room_for_new_orb : Test(2) {
    my $self = shift;

    my @land = $self->_create_land();

    $land[0]->terrain_id( $self->{town_terrain}->id );
    $land[0]->update;
    $land[4]->terrain_id( $self->{town_terrain}->id );
    $land[4]->update;
    $land[8]->terrain_id( $self->{town_terrain}->id );
    $land[8]->update;

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs, 0, "Should be no orbs" );
    $self->{logger}->called_ok( 'warn', "Warning should be written to log file" );
}

sub test_spawn_monsters : Tests(4) {
    my $self = shift;

    my @land = $self->_create_land();

    # Orb in top left
    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[0]->id, } );

    # Create a party to force some monsters to be generated
    $self->{schema}->resultset('Party')->create({});

    RPG::Ticker->spawn_monsters( $self->{config}, $self->{schema}, $self->{logger} );
    
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search(
        {},
        {
            prefetch => 'location',
        }
    );
    is(scalar @cgs, 5, "Five groups generated");
    
    # Find out the distance of each cg from the orb. 3 should be 1 sector, 1 should be 2 sectors
    my %distance;
    foreach my $cg (@cgs) {        
        my $dist = RPG::Map->get_distance_between_points(
            {
                x => $land[0]->x,
                y => $land[0]->y,
            },
            {
                x => $cg->location->x,
                y => $cg->location->y,
            }
        );
        
        $distance{$dist}++;
    }
        
    is($distance{0}, 1, "1 cgs 0 square from the orb");
    is($distance{1}, 3, "3 cgs 1 square from the orb");
    is($distance{2}, 1, "1 cgs 2 squares from the orb");
}

sub _create_land {
    my $self = shift;

    my $non_town_terrain = $self->{schema}->resultset('Terrain')->create( { terrain_name => 'non_town_terrain', } );

    $self->{town_terrain} = $self->{schema}->resultset('Terrain')->create( { terrain_name => 'town', } );

    my @land;
    for my $x ( 1 .. 3 ) {
        for my $y ( 1 .. 3 ) {
            push @land, $self->{schema}->resultset('Land')->create(
                {
                    x          => $x,
                    y          => $y,
                    terrain_id => $non_town_terrain->id,
                }
            );
        }
    }

    return @land;
}

1;
