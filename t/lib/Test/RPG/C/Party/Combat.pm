use strict;
use warnings;

package Test::RPG::C::Party::Combat;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Party_Battle;
use Test::RPG::Builder::Combat_Log;

use RPG::C::Party::Combat;

sub test_fight : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    
    $self->{stash}{party} = $party1;
    
    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );
    
    my $mock_battle = Test::MockObject::Extra->new();    
    my %new_args;
    $mock_battle->fake_module(
    	'RPG::Combat::PartyWildernessBattle',
        new => sub { shift @_; %new_args = @_; return $mock_battle },
    );
    $mock_battle->mock('execute_round', sub {});
    
    $self->{mock_forward}{'/combat/process_round_result'} = sub {};
    
    # WHEN
    RPG::C::Party::Combat->fight($self->{c});
    
    # THEN
    is($new_args{party_1}, $party1, "Actual party reference passed in to battle object");
    is($new_args{party_2}->id, $party2->id, "Correct party record passed as secont party");
    
    $mock_battle->unfake_module('RPG::Combat::PartyWildernessBattle');    
}

sub test_attack_error_when_too_many_offline_combats : Tests(1) {
    my $self = shift;	
	
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $party1->land_id );
    $party2->last_action(DateTime->now->subtract( minutes => 5 ));
    $party2->update;
    
    $self->{config}{max_party_offline_attacks} = 1;	
    
    $self->{stash}{party} = $party1;
    $self->{params}{party_id} = $party2->id;
    
    $self->{mock_forward}{'/panel/refresh'} = sub {};
    
    my $log = Test::RPG::Builder::Combat_Log->build_log($self->{schema}, opp_1 => $party2);
    my $log2 = Test::RPG::Builder::Combat_Log->build_log($self->{schema}, opp_1 => $party2);
    
    # WHEN
    RPG::C::Party::Combat->attack($self->{c});
    
    # THEN
    is($self->{stash}{error}, 'This party has been attacked too many times recently', "Correct error message");
    
}

sub test_attack_error_when_old_offline_combats : Tests(1) {
    my $self = shift;	
	
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $party1->land_id );
    $party2->last_action(DateTime->now->subtract( minutes => 5 ));
    $party2->update;
    
    $self->{config}{max_party_offline_attacks} = 1;	
    
    $self->{stash}{party} = $party1;
    $self->{params}{party_id} = $party2->id;
    
    $self->{mock_forward}{'/panel/refresh'} = sub {};
    
    my $log = Test::RPG::Builder::Combat_Log->build_log($self->{schema}, opp_1 => $party2, encounter_ended => DateTime->now->subtract(minutes => 10));
    
    # WHEN
    RPG::C::Party::Combat->attack($self->{c});
    
    # THEN
    is($self->{stash}{error}, undef, "No error message");
    
}

1;