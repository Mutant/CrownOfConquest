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
    
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema});    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, in_combat_with => $cg->id, last_action => DateTime->now->subtract(minutes=>15));

    my $offline_combat_action = RPG::NewDay::Action::OfflineCombat->new( context => $self->{mock_context} );
    
    $offline_combat_action = Test::MockObject::Extends->new($offline_combat_action);
    $offline_combat_action->set_always('execute_offline_battle');
    
    $self->{config}{online_threshold} = 10;
    
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
}

1;