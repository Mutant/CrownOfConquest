use strict;
use warnings;

package Test::RPG::NewDay::CreatureOrbs;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

use RPG::Ticker::LandGrid;

use Test::RPG::Builder::Land;

sub setup_orb_data : Test(startup=>1) {
    my $self = shift;

    my $logger = Test::MockObject->new();
    $logger->set_true('warning');
    $logger->set_true('info');
    $logger->set_true('debug');

    $self->{logger} = $logger;

    $self->{context} = Test::MockObject->new();
    $self->{context}->set_always( 'logger', $logger );
    $self->{context}->set_always( 'schema', $self->{schema} );
    $self->{context}->mock( 'config',    sub { $self->{config} } );
    $self->{context}->mock( 'land_grid', sub { $self->{land_grid} } );
    $self->{context}->set_isa('RPG::NewDay::Context');

    use_ok('RPG::NewDay::Action::CreatureOrbs');

    $self->{creature_orbs} = RPG::NewDay::Action::CreatureOrbs->new( context => $self->{context} );
}

sub setup_orb_config : Test(setup) {
    my $self = shift;

    $self->{config} = {
        land_per_orb                     => 4,
        orb_distance_from_town_per_level => 1,
        max_orb_level                    => 1,
        orb_distance_from_other_orb      => 1,
    };
    
    $self->{cret_category} = $self->{schema}->resultset('Creature_Category')->create(
    	{
    		name => 'Test',
    	},
    );        
    
    $self->{creature_type_1} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 1,
            creature_category_id   => $self->{cret_category}->id,
        }
    );

    $self->{creature_type_2} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 2,
            creature_category_id   => $self->{cret_category}->id,
        }
    );

    $self->{creature_type_3} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 3,
            creature_category_id   => $self->{cret_category}->id,
        }
    );    
}

sub test_spawn_orbs_successful_run : Tests(7) {
    my $self = shift;

    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    # Towns on top left and bottom right corners
    for my $idx ( 0, 8 ) {
        $self->{schema}->resultset('Town')->create( { 'land_id' => $land[$idx]->id } );
    }

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_orbs}->spawn_orbs();

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

sub test_spawn_orb_successful_run_with_existing_orb : Test(2) {
    my $self = shift;

    return "Test fails periodically - needs a rewrite";

    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    # Town on top left corner
    $self->{schema}->resultset('Town')->create( { 'land_id' => $land[0]->id } );

    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[2]->id, } );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_orbs}->spawn_orbs();

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs,      2, "Should be two orbs" );
    is( $orbs[1]->land->x, 3, "Second orb created on bottom row" );

}

sub test_spawn_orbs_successful_run_with_existing_cg : Tests(8) {
    my $self = shift;

    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    # Towns on top left and bottom right corners
    for my $idx ( 0, 8 ) {
        $self->{schema}->resultset('Town')->create( { 'land_id' => $land[$idx]->id } );
    }

    my $existing_cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[2]->id, }, );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_orbs}->spawn_orbs();

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs,      2, "Should be two orbs" );
    is( $orbs[0]->land->x, 1, "First orb should be at x=1" );
    is( $orbs[0]->land->y, 3, "First orb should be at y=3" );

    my @spawned_cgs = $orbs[0]->land->search_related('creature_group');

    is( scalar @spawned_cgs, 1, "Creature group spawned at first orb" );
    is( $spawned_cgs[0]->id, $existing_cg->id, "Didn't spawn a new cg, as one already there" );

    is( $orbs[1]->land->x, 3, "Second orb should be at x=3" );
    is( $orbs[1]->land->y, 1, "Second orb should be at y=1" );

    @spawned_cgs = $orbs[1]->land->search_related('creature_group');
    is( scalar @spawned_cgs, 1, "Creature group spawned at first orb" );
}

sub test_spawn_orb_with_town_search_smaller_than_orb_search : Test(1) {
    my $self = shift;

    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 5, 'y_size' => 5 );

    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[12]->id, } );

    $self->{config}->{orb_distance_from_other_orb} = 3;

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_orbs}->spawn_orbs();

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs, 1, "Should only be one orb" );

}

sub test_spawn_orb_no_room_for_new_orb : Test(2) {
    my $self = shift;

    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    for my $idx ( 0, 4, 8 ) {
        $self->{schema}->resultset('Town')->create( { 'land_id' => $land[$idx]->id } );
    }

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_orbs}->spawn_orbs();

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs, 0, "Should be no orbs" );
    $self->{logger}->called_ok( 'warning', "Warning should be written to log file" );
}

1;
