use strict;
use warnings;

package Test::RPG::Combat::GarrisonCreatureBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;
use Test::MockObject::Extends;

use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Character;

use RPG::Combat::GarrisonCreatureBattle;

sub setup : Tests(setup) {
    my $self = shift;
    
    Test::RPG::Builder::Day->build_day( $self->{schema} );
    
    $self->mock_dice;
}

sub teardown : Tests(teardown) {
	my $self = shift;
	
	$self->{dice}->unfake_module();	
}

sub test_new : Tests(1) {
	my $self = shift;
	
	# GIVEN
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id );
	
	# WHEN
	my $battle = RPG::Combat::GarrisonCreatureBattle->new(
        schema             => $self->{schema},
        garrison           => $garrison,
        creature_group     => $cg,
        log                => $self->{mock_logger},
    );
    
    # THEN
    isa_ok($battle, 'RPG::Combat::GarrisonCreatureBattle', "Object instatiated correctly");
}

sub test_check_for_flee : Tests(3) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	$character->garrison_id($garrison->id);
	$character->update;
	
	$garrison = Test::MockObject::Extends->new($garrison);
	$garrison->set_true('is_over_flee_threshold');
	
	my $config = {
		base_flee_chance => 20,
		flee_chance_level_modifier => 20,	
		flee_chance_attempt_modifier => 1,
		flee_chance_low_level_bonus => 1,
	};
	
	$self->{roll_result} = 1;
	
	my $battle = RPG::Combat::GarrisonCreatureBattle->new(
        schema             => $self->{schema},
        garrison           => $garrison,
        creature_group     => $cg,
        log                => $self->{mock_logger},
        config			   => $config,
    );
    
    # WHEN
    my $result = $battle->check_for_flee();
    
    # THEN
    is($result, 1, "Garrison fled from battle");
    
    $garrison->discard_changes();
    isnt($garrison->land_id, $land[4]->id, "No longer in original location");
    is($battle->result->{party_fled}, 1, "Correct value set in battle result"); 	
		
}

1;