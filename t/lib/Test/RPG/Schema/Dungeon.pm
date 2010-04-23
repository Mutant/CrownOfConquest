package Test::RPG::Schema::Dungeon;

use strict;
use warnings;

use base qw(Test::RPG);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Data::Dumper;

sub startup : Test(startup => 1) {
	my $self = shift;
	
    $self->{mock_rpg_schema} = Test::MockObject->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );	
	
	use_ok 'RPG::Schema::Dungeon';
}

sub dungeon_shutdown : Tests(shutdown) {
	my $self = shift;
	$self->{mock_rpg_schema}->unfake_module();	
}

sub test_party_can_enter_instance : Test(3) {
    my $self = shift;
    
    # GIVEN
    my $mock_party = Test::MockObject->new();
    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_isa('RPG::Schema::Dungeon');
    
    $self->{config}{dungeon_entrance_level_step} = 5;
    
    my %tests = (
        low_level_party_allowed_to_enter_level_1_dungeon => {
            party_level => 1,
            dungeon_level => 1,
            expected_result => 1,
        },
        low_level_party_not_allowed_to_enter_level_2_dungeon => {
            party_level => 4,
            dungeon_level => 2,
            expected_result => 0,
        },
        level_5_party_allowed_to_enter_level_2_dungeon => {
            party_level => 5,
            dungeon_level => 2,
            expected_result => 1,
        },
    );
    
    # WHEN
    my %results;
    while (my ($test_name, $test_data) = each %tests) {        
        $mock_party->set_always('level',$test_data->{party_level});
        $mock_dungeon->set_always('level',$test_data->{dungeon_level});    
        $results{$test_name} = RPG::Schema::Dungeon::party_can_enter($mock_dungeon, $mock_party);
    }
    
    # THEN
    while (my ($test_name, $test_data) = each %tests) {
        is($results{$test_name}, $tests{$test_name}->{expected_result}, "Got expected result for: $test_name");
    }
}

sub test_party_can_enter_class : Test(1) {
    my $self = shift;
    
    # GIVEN
    my $mock_party = Test::MockObject->new();
    $mock_party->set_always('level',10);
    
    $self->{config}{dungeon_entrance_level_step} = 5;
    
    # WHEN
    my $result = RPG::Schema::Dungeon->party_can_enter(4, $mock_party);
    
    is($result, 0, "Successfully called party_can_enter as class method");
}

1;