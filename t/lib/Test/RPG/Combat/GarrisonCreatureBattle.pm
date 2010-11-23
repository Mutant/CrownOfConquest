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
use Test::RPG::Builder::Item;

sub setup : Tests(setup => 2) {
    my $self = shift;
    
    Test::RPG::Builder::Day->build_day( $self->{schema} );
    
    use_ok 'RPG::Combat::GarrisonCreatureBattle';
    use_ok 'RPG::Template';
    
    $self->mock_dice;
}

sub teardown : Tests(teardown) {
	my $self = shift;
	
	$self->unmock_dice;
}

sub test_new : Tests(2) {
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
    $garrison->discard_changes;
    is($garrison->in_combat_with, $cg->id, "Garrison now in combat with CG");
}

sub test_check_for_flee : Tests(8) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, garrison_id => $garrison->id );
	
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
    is($garrison->gold, 0, "Garrison lost all its gold");
    is($battle->result->{party_fled}, 1, "Correct value set in battle result"); 	
    
    $item->discard_changes();
    is($item->garrison_id, undef, "Garrison equipment no longer in storage");
    is($item->land_id, $land[4]->id, "Item in original sector");
    
    undef $battle;
    
    my ($combat_log) = $self->{schema}->resultset('Combat_Log')->search();
    is($combat_log->outcome, 'opp1_fled', "Correct combat log outcome");
    is(defined $combat_log->encounter_ended, 1, "Encounter ended set in combat log");
		
}

sub test_finish_garrison_lost : Test(5) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, character_count => 2);
	
	my @characters = $garrison->characters;
	
	$self->{config}{nearby_town_range} = 1;
	my $battle = RPG::Combat::GarrisonCreatureBattle->new(
        schema             => $self->{schema},
        garrison           => $garrison,
        creature_group     => $cg,
        log                => $self->{mock_logger},
        config			   => $self->{config},
    );	
	
	# WHEN
	$battle->finish($garrison);
	
	# THEN
	$garrison->discard_changes;
	is($garrison->land_id, undef, "Garrison removed");
	
	foreach my $char (@characters) {
		$char->discard_changes;
		is($char->party_id, undef, "Character removed from party");
		is($char->garrison_id, undef, "Character removed from garrison");
	}
}

sub test_finish_garrison_won : Test(1) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	
	$self->{roll_result} = 10;
	
	my $battle = RPG::Combat::GarrisonCreatureBattle->new(
        schema             => $self->{schema},
        garrison           => $garrison,
        creature_group     => $cg,
        log                => $self->{mock_logger},
        config			   => {nearby_town_range => 1},
    );	
	
	# WHEN
	$battle->finish($cg);
	
	# THEN
	$garrison->discard_changes;
	is($garrison->gold, 10, "Garrison gold increased");
}

sub test_execute_round : Tests(1) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	$character->garrison_id($garrison->id);
	$character->update;
	
	my $home = $ENV{RPG_HOME};
    $self->{config} = {
        attack_dice_roll                      => 10,
        defence_dice_roll                     => 10,
        creature_defence_base                 => 5,
        create_defence_factor_increment       => 5,
        creature_attack_base                  => 5,
        create_attack_factor_increment        => 5,
        maximum_turns                         => 300,
        xp_multiplier                         => 10,
        chance_to_find_item                   => 0,
        prevalence_per_creature_level_to_find => 1,
        nearby_town_range                     => 5,
        front_rank_attack_chance              => 5,
        home => $home,
    };

    my $battle = RPG::Combat::GarrisonCreatureBattle->new(
        schema         => $self->{schema},
        garrison       => $garrison,
        creature_group => $cg,
        config         => $self->{config},
        log            => $self->{mock_logger},
    );
    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'check_for_flee', undef );    
    $battle->set_true('process_effects');

    # WHEN
    my $result = $battle->execute_round();

    # THEN
    is( $result->{combat_complete}, undef, "Combat hasn't ended" );
}

1;