use strict;
use warnings;

package Test::RPG::C::Combat;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;

sub combat_startup : Test(startup => 1) {
    my $self = shift;

    use_ok('RPG::C::Combat');
}

sub test_fight : Tests(5) {
    my $self = shift;

    # GIVEN
    my $result = { messages => 'messages from combat', };

    my $mock_battle = Test::MockObject->new();
    my %new_args;
    $mock_battle->fake_module(
        'RPG::Combat::CreatureWildernessBattle',
        new => sub {
            shift @_;
            %new_args = @_;
            return $mock_battle;
        },
    );
    $mock_battle->mock(
        'execute_round',
        sub {
            return $result;
        },
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Combat->fight( $self->{c} );

    # THEN
    is( $new_args{creature_group}->id, $cg->id,    "Creature group passed in correctly" );
    is( $new_args{party}->id,          $party->id, "Creature group passed in correctly" );
    is( $new_args{creatures_can_flee}, 1,          "Creatures allowed to flee" );
    $mock_battle->called_ok('execute_round');

    is( $template_args->[0][0]{params}{combat_messages}, "messages from combat", "Combat messages passed to template" );
}

sub test_flee_flee_successful : Tests(7) {
    my $self = shift;

    # GIVEN
    my $result = { party_fled => 1, };

    my $mock_battle = Test::MockObject->new();
    my %new_args;
    $mock_battle->fake_module(
        'RPG::Combat::CreatureWildernessBattle',
        new => sub {
            shift @_;
            %new_args = @_;
            return $mock_battle;
        },
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;
    
    my $orig_location = $party->land_id;

    $mock_battle->mock(
        'execute_round',
        sub {
            $party->land_id($party->land_id+1);
            $party->update;
            return $result;
        },
    );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Combat->flee( $self->{c} );

    # THEN
    is( $new_args{creature_group}->id, $cg->id,    "Creature group passed in correctly" );
    is( $new_args{party}->id,          $party->id, "Creature group passed in correctly" );
    is( $new_args{creatures_can_flee}, 1,          "Creatures allowed to flee" );
    is( $new_args{party_flee_attempt}, 1,          "Flee attempted");
    is( $self->{stash}{messages}, "You got away!", "Flee message set");
    is( $self->{stash}{party}->land_id, $orig_location+1, "Party record in stash refreshed");
    is( $self->{stash}{creature_group}, undef, "Creature group in stash cleared");
    
}

sub test_select_action : Tests(3) {
    my $self = shift;
        
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    
    $self->{params}{action_param} = ['1','2'];
	$self->{params}{character_id} = $character->id;
	$self->{params}{action} = 'Attack';
	
	$self->{mock_forward}{'/panel/refresh'} = sub { };
	
	# WHEN
	RPG::C::Combat->select_action($self->{c});
	
	# THEN
	$character->discard_changes;
	is($character->last_combat_action, 'Attack', "Last combat action set correctly");
	is($character->last_combat_param1, '1', "Last action param 1 set correctly");
	is($character->last_combat_param2, '2', "Last action param 2 set correctly");
	 
       
}

1;
