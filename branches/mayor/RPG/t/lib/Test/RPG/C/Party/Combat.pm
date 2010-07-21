use strict;
use warnings;

package Test::RPG::C::Party::Combat;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Party_Battle;

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
    
    my $mock_battle = Test::MockObject->new();    
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

1;