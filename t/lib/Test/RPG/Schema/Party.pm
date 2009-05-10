use strict;
use warnings;

package Test::RPG::Schema::Party;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;

use Data::Dumper;
use DateTime;

sub startup : Tests(startup=>1) {
    my $self = shift;

    my $mock_config = Test::MockObject->new();

    $self->{config} = {};

    $mock_config->fake_module( 'RPG::Config', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::Party';
}

sub test_new_day : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $mock_party = Test::MockObject->new();
    $mock_party->set_always( 'turns', 100 );
    $mock_party->mock( 'characters', sub { () } );
    $mock_party->set_true('rest');
    $mock_party->set_true('update');
    $mock_party->set_true('add_to_day_logs');

    $self->{config} = {
        daily_turns         => 10,
        maximum_turns       => 200,
        min_heal_percentage => 10,
        max_heal_percentage => 20,
    };

    my $mock_new_day = Test::MockObject->new();
    $mock_new_day->set_always( 'id', 5 );

    # WHEN
    RPG::Schema::Party::new_day( $party, $mock_new_day );

    # THEN
    $party->discard_changes;
    is($party->turns, 110, "Party turns incremented");
    is($party->rest, 0, "Rest is set to 0");

}

sub test_in_party_battle_with : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema});
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema});
    
    my $battle = $self->{schema}->resultset('Party_Battle')->create(
        {
            complete => undef,
        }
    );
    
    $self->{schema}->resultset('Battle_Participant')->create(
        {
            party_id => $party1->id,
            battle_id => $battle->id,
        }
    );
    
    $self->{schema}->resultset('Battle_Participant')->create(
        {
            party_id => $party2->id,
            battle_id => $battle->id,
        }
    );
    
    # WHEN
    my $p1_opp = $party1->in_party_battle_with;
    my $p2_opp = $party2->in_party_battle_with;
    
    # THEN
    is($p1_opp->id, $party2->id, "Party 1 in combat with party 2");
    is($p2_opp->id, $party1->id, "Party 2 in combat with party 1");
}

sub test_over_flee_threshold_no_damage : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, hit_points => 10, max_hit_points => 10);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 0, "Party not over threshold");    
}

sub test_over_flee_threshold_on_threshold : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, hit_points => 7, max_hit_points => 10);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 0, "Party not over threshold");    
}

sub test_over_flee_threshold_below_threshold : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 1, "Party over threshold");    
}

sub test_is_online_party_online : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    $party->last_action(DateTime->now());
    $party->update;
    
    $self->{config}{online_threshold} = 100;
    
    # WHEN
    my $online = $party->is_online;
    
    # THEN
    is($online, 1, "Party is online");    
}

sub test_is_online_party_offline : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    $party->last_action(DateTime->now()->subtract( minutes => 2 ));
    $party->update;
    
    $self->{config}{online_threshold} = 1;
    
    # WHEN
    my $online = $party->is_online;
    
    # THEN
    is($online, 0, "Party is offline");    
}

sub test_turns_used_incremented : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    
    # WHEN
    $party->turns(50);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns_used, 50, "Correct number of turns used recorded");
}

sub test_turns_used_party_above_maximum_turns : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    # Party has 100, but max is 99... this could happen if e.g. the max turns was reduced
    $self->{config}{maximum_turns} = 99;
    
    # WHEN
    $party->turns(99);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns_used, 1, "Correct number of turns used recorded");
}

sub test_turns_used_not_increased_when_adding_turns : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    $self->{config}{maximum_turns} = 101;
    
    # WHEN
    $party->increase_turns(102);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns_used, 0, "Correct number of turns used recorded");
}

sub test_turns_not_lost_if_above_maximum : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    # Party has 100, but max is 99... this could happen if e.g. the max turns was reduced
    $self->{config}{maximum_turns} = 98;
    
    # WHEN
    $party->turns(99);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns, 99, "Turns allowed to remain above maximum");
}

sub test_turns_cant_by_increased_by_calling_turns_method : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    
    # WHEN
    my $e;
    eval {
        $party->turns(101);
        $party->update;
    };
    if ($@) {
        $e = $@;        
    }    
    
    # THEN
    isa_ok($e, 'RPG::Exception', "Exception thrown");
    is($e->type, 'increase_turns_error', "Exception is correct type");
    $party->discard_changes;
    is($party->turns, 100, "Turns not changed");
}

sub test_turns_cant_by_decreased_by_calling_increase_turns_method : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    
    # WHEN
    my $e;
    eval {
        $party->increase_turns(99);
        $party->update;
    };
    if ($@) {
        $e = $@;        
    }    
    
    # THEN
    isa_ok($e, 'RPG::Exception', "Exception thrown");
    is($e->type, 'increase_turns_error', "Exception is correct type");
    $party->discard_changes;
    is($party->turns, 100, "Turns not changed");
}

sub test_turns_cant_be_increased_above_maximum : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    
    $self->{config}{maximum_turns} = 105;
    
    # WHEN
    $party->increase_turns(110);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns, 105, "Turns set to maximum");
}

1;
