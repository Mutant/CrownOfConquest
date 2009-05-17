package Test::RPG::Schema::CreatureGroup;

use strict;
use warnings;

use base qw(Test::RPG);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;


sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{mock_rpg_schema} = Test::MockObject->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );

    $self->{dice} = Test::MockObject->fake_module( 'Games::Dice::Advanced', roll => sub { $self->{roll_result} || 0 }, );

    use_ok 'RPG::Schema::CreatureGroup';
}

sub shutdown : Test(shutdown) {
	my $self = shift;
	
	delete $INC{'Games/Dice/Advanced.pm'};
	require 'Games/Dice/Advanced.pm';
	
	delete $INC{'RPG/Schema.pm'};
	require 'RPG/Schema.pm';
}

sub test_initiate_combat : Test(6) {
    my $self = shift;

    my $creature_group = Test::MockObject->new();
    $creature_group->set_always( 'location', $creature_group );
    $creature_group->set_always( 'land_id', 1 );
    $creature_group->mock('party_within_level_range', sub { RPG::Schema::CreatureGroup::party_within_level_range(@_) } );

    my $party = Test::MockObject->new();
    $party->set_true('level');

    # Orb at cg's location, and party is high enough level, so combat initiated
    $creature_group->set_always( 'orb',         $creature_group );
    $creature_group->set_always( 'can_destroy', 1 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 1, "Combat initiated for high enough level party with Orb" );

    # Party not high enough level for orb, and too low for cg
    $creature_group->set_always( 'can_destroy', 0 );
    $self->{config}{cg_attack_max_factor_difference} = 2;
    $self->{config}{cg_attack_max_level_below_party} = 2;
    $party->set_always( 'level', 1 );
    $creature_group->set_always( 'level', 4 );
    $creature_group->set_always('compare_to_party',1);

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated since party too low level" );

    # Party not high enough level for orb, and too high for cg
    $creature_group->set_always( 'can_destroy', 0 );
    $self->{config}{cg_attack_max_factor_difference} = 2;
    $party->set_always( 'level', 5 );
    $creature_group->set_always( 'level', 2 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated since party too high level" );

    # No orb, and too high for cg
    $creature_group->set_always( 'orb', undef );
    $self->{config}{cg_attack_max_factor_difference} = 4;
    $party->set_always( 'level', 7 );
    $creature_group->set_always( 'level', 2 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated since party too high level" );
    
    $self->{config}{cg_attack_max_factor_difference} = 1;
    $self->{config}{cg_attack_max_level_below_party} = 2;
    $self->{config}{creature_attack_chance} = 40;
    $party->set_always( 'level', 7 );
    $creature_group->set_always( 'level', 7 );

    # Party right level, but roll higher than chance    
    $self->{roll_result} = 60; 
    
    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated roll too high" );

    # Party right level, but roll higher than chance    
    $self->{roll_result} = 30; 
    
    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 1, "Combat initiated, roll less than chance" );
}

sub test_party_within_level_range : Tests(5) {
    my $self = shift;
    
    # GIVEN
    $self->{config}->{cg_attack_max_factor_difference} = 2;
    $self->{config}->{cg_attack_max_level_below_party} = 4;
    
    my @tests = (
        {
            party_level => 1,
            creature_group_level => 1,            
            factor_comparison => 3,
            expected_result => 1,
        },
        {
            party_level => 1,
            creature_group_level => 4,
            factor_comparison => 1,
            expected_result => 0,
        },     
        {
            party_level => 1,
            creature_group_level => 3,
            factor_comparison => 3,
            expected_result => 1,
        },          
        {
            party_level => 6,
            creature_group_level => 1,
            factor_comparison => 1,
            expected_result => 0,
        },    
        {
            party_level => 5,
            creature_group_level => 1,
            factor_comparison => 1,
            expected_result => 1,
        },                
    ); 
    
    # WHEN
    my @results;
    foreach my $test (@tests) {
        my $mock_cg = Test::MockObject->new();
        $mock_cg->set_always('level', $test->{creature_group_level});
        $mock_cg->set_always('compare_to_party', $test->{factor_comparison});
        
        my $mock_party = Test::MockObject->new();
        $mock_party->set_always('level', $test->{party_level});
        
        push @results, RPG::Schema::CreatureGroup::party_within_level_range($mock_cg, $mock_party);        
    }
    
    my $count = 0;
    foreach my $test (@tests) {
        is($results[$count], $test->{expected_result}, "Result ok for test $count");
        $count++;   
    }
}

1;
