use strict;
use warnings;

package Test::RPG::NewDay::OfflineCombat;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Day;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Dungeon_Grid;

use DateTime;

sub offline_startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::OfflineCombat';
}

sub setup : Test(setup) {
    my $self = shift;

    my $day = Test::RPG::Builder::Day->build_day( $self->{schema} );

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema',    $self->{schema} );
    $mock_context->set_always( 'config',    $self->{config} );
    $mock_context->set_always( 'yesterday', $day );
    $mock_context->set_always( 'logger',    $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    $self->{mock_context} = $mock_context;
    
    $self->{rolls} = undef;
    $self->{roll_result} = undef;
}

sub test_complete_battles : Tests(5) {
    my $self = shift;  
    
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, land_id => $land[0]->id);    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, 
    	in_combat_with => $cg->id, last_action => DateTime->now->subtract(minutes=>15), combat_type => 'creature_group',
    	land_id => $land[0]->id
    );

    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_always('execute_offline_battle');
    
    $self->{config}{online_threshold} = 10;
    $self->{config}{max_offline_combat_count} = 3;
    
    # WHEN
    $offline_combat_action->complete_battles();
    
    # THEN
    my ($method, $args) = $offline_combat_action->next_call();
    
    is($method, 'execute_offline_battle', "Offline battle executed");
    isa_ok($args->[1], 'RPG::Schema::Party', "Party passed to offline battle");
    is($args->[1]->id, $party->id, "Correct party passed");
    isa_ok($args->[2], 'RPG::Schema::CreatureGroup', "CG passed to offline battle");
    is($args->[2]->id, $cg->id, "Correct cg passed");  
    
}

sub test_complete_battles_doesnt_trigger_in_dungeons : Tests(1) {
    my $self = shift;  
    
    # GIVEN
    my $dungeon_sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema});
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $dungeon_sector->id);    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, 
    	in_combat_with => $cg->id, last_action => DateTime->now->subtract(minutes=>15), combat_type => 'creature_group',
    	dungeon_grid_id => $dungeon_sector->id,
    );

    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_always('execute_offline_battle');
    
    $self->{config}{online_threshold} = 10;
    $self->{config}{max_offline_combat_count} = 3;
    
    # WHEN
    $offline_combat_action->complete_battles();
    
    # THEN
    my ($method, $args) = $offline_combat_action->next_call();
    
    is($method, undef, "Combat not executed, as cg in dungeon"); 
    
}

sub test_initiate_battles : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $land = $land[0];
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, land_id => $land->id, last_action => DateTime->now->subtract(minutes=>15));
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, land_id => $land->id);
    
    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_always('execute_offline_battle');
    
    $self->{config}{online_threshold} = 10;
    $self->{config}{offline_combat_chance} = 35;
    $self->{config}{max_offline_combat_count} = 3;
    
    $self->mock_dice;
    
    $self->{roll_result} = 35;
    
    # WHEN
    $offline_combat_action->initiate_battles();
    
    # THEN
    my ($method, $args) = $offline_combat_action->next_call();
    
    is($method, 'execute_offline_battle', "Offline battle executed");
    isa_ok($args->[1], 'RPG::Schema::Party', "Party passed to offline battle");
    is($args->[1]->id, $party->id, "Correct party passed");
    isa_ok($args->[2], 'RPG::Schema::CreatureGroup', "CG passed to offline battle");
    is($args->[2]->id, $cg->id, "Correct cg passed");    
    
    $self->unmock_dice;
}

sub test_initiate_battles_garrison : Tests(5) {
    my $self = shift;
        
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $land = $land[0];
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land->id);
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, land_id => $land->id);
    
    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_always('execute_garrison_battle');
    
    $self->{config}{garrison_combat_chance} = 35;
    
    $self->mock_dice;
    
    $self->{roll_result} = 35;
    
    # WHEN
    $offline_combat_action->initiate_battles();
    
    # THEN
    my ($method, $args) = $offline_combat_action->next_call();
    
    is($method, 'execute_garrison_battle', "Garrison battle executed");
    isa_ok($args->[1], 'RPG::Schema::Garrison', "Party passed to offline battle");
    is($args->[1]->id, $garrison->id, "Correct party passed");
    isa_ok($args->[2], 'RPG::Schema::CreatureGroup', "CG passed to offline battle");
    is($args->[2]->id, $cg->id, "Correct cg passed");   
    
    $self->unmock_dice; 
}

sub test_initiate_battles_garrison_vs_party : Tests(5) {
    my $self = shift;
        
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $land = $land[0];
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema});
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party1->id, land_id => $land->id);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, land_id => $land->id, 
    	last_action => DateTime->now()->subtract( minutes => 20 ));
    
    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_true('execute_garrison_battle');
    $offline_combat_action->set_true('check_for_garrison_fight');
    
    
    # WHEN
    $offline_combat_action->initiate_battles();
    
    # THEN
    my ($method, $args) = $offline_combat_action->next_call(2);
    
    is($method, 'execute_garrison_battle', "Garrison battle executed");
    isa_ok($args->[1], 'RPG::Schema::Garrison', "Garrison passed to offline battle");
    is($args->[1]->id, $garrison->id, "Correct garrison passed");
    isa_ok($args->[2], 'RPG::Schema::Party', "Party passed to offline battle");
    is($args->[2]->id, $party2->id, "Correct party passed"); 
}

sub test_initiate_battles_garrison_vs_own_party : Tests(1) {
    my $self = shift;
        
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $land = $land[0];
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, land_id => $land->id,
    	last_action => DateTime->now()->subtract( minutes => 20 ));
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party1->id, land_id => $land->id);
    
    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_true('execute_garrison_battle');
    $offline_combat_action->set_true('check_for_garrison_fight');    
    
    # WHEN
    $offline_combat_action->initiate_battles();
    
    # THEN
    my ($method, $args) = $offline_combat_action->next_call(2);
    
    is($method, undef, "Garrison battle not executed, as garrison belongs to party");
}

sub test_initiate_battles_against_cg_with_no_living_creatures : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $land = $land[0];
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, land_id => $land->id, 
    	last_action => DateTime->now->subtract(minutes=>15), character_count => 2);
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, land_id => $land->id, creature_hit_points_current => 0);
    
    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $self->{config}{online_threshold} = 10;
    $self->{config}{offline_combat_chance} = 35;
    $self->{config}{max_offline_combat_count} = 3;
    
    $self->mock_dice;
    
    $self->{roll_result} = 35;
    
    # WHEN
    $offline_combat_action->initiate_battles();
    
    # THEN
    my $combat_log = $self->{schema}->resultset('Combat_Log')->find(
    	{
    		opponent_1_id => $party->id,
    		opponent_1_type => 'party',
    		opponent_2_id => $cg->id,
    		opponent_2_type => 'creature_group',
    	}
    );
    is(defined $combat_log, 1, "Combat log was generated");
	is($combat_log->outcome, 'opp1_won', "Party won the combat");
	is($combat_log->rounds, 1, "Only round round, as all cgs were already dead");
    
    $self->unmock_dice;
}

1;