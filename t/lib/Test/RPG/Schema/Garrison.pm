use strict;
use warnings;

package Test::RPG::Schema::Garrison;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Creature_Orb;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Kingdom;

sub test_find_fleeable_sectors_all_sectors_clear : Tests(9) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	
	# WHEN
	my @fleeable_sectors = $garrison->find_fleeable_sectors();
	
	# THEN
	is(scalar @fleeable_sectors, 8, "8 sectors are fleeable");
	for my $idx (0..8) {
		next if $idx == 4;
		my $in_land_array = grep { $_->id == $land[$idx]->id } @fleeable_sectors;
		is(	$in_land_array, 1, "Correct sector returned");
	}
}

sub test_find_fleeable_sectors_some_sectors_occupied : Tests(6) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[1]->id );
	my $garrison2 = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[2]->id, );
	my $orb = Test::RPG::Builder::Creature_Orb->build_orb( $self->{schema}, land_id => $land[6]->id, );
	
	# WHEN
	my @fleeable_sectors = $garrison->find_fleeable_sectors();
	
	# THEN
	is(scalar @fleeable_sectors, 5, "5 sectors are fleeable");
	
	my @expected = qw/0 3 5 7 8/;
	
	for my $idx (@expected) {
		my $in_land_array = grep { $_->id == $land[$idx]->id } @fleeable_sectors;
		is(	$in_land_array, 1, "Correct sector returned");
	}
}

sub test_check_for_fight_vs_party_even : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
	);
	my $party2 = Test::RPG::Builder::Party->build_party($self->{schema});	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 3);
	
	$self->{config}{min_party_level_for_garrison_attack} = 1;
	
	# WHEN / THEN
	$garrison->party_attack_mode('Attack Weaker Opponents');
	is($garrison->check_for_fight($party), 0, "Doesn't attack when set to attack weaker");

	$garrison->party_attack_mode('Attack Similar Opponents');
	is($garrison->check_for_fight($party), 1, "Attacks when set to attack similar");
	
	$garrison->party_attack_mode('Attack Stronger Opponents');
	is($garrison->check_for_fight($party), 1, "Attacks when set to attack stronger");  
}

sub test_check_for_fight_vs_party_weaker : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
	);
	my $party2 = Test::RPG::Builder::Party->build_party($self->{schema});	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 6);
	
	$self->{config}{min_party_level_for_garrison_attack} = 1;
	
	# WHEN / THEN
	$garrison->party_attack_mode('Attack Weaker Opponents');
	is($garrison->check_for_fight($party), 1, "Attacks when set to attack weaker");

	$garrison->party_attack_mode('Attack Similar Opponents');
	is($garrison->check_for_fight($party), 1, "Attacks when set to attack similar");
	
	$garrison->party_attack_mode('Attack Stronger Opponents');
	is($garrison->check_for_fight($party), 1, "Attacks when set to attack stronger");       
}

sub test_check_for_fight_vs_party_stronger : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 5,
	);
	my $party2 = Test::RPG::Builder::Party->build_party($self->{schema});	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 2);
	
	$self->{config}{min_party_level_for_garrison_attack} = 1;
	
	# WHEN / THEN
	$garrison->party_attack_mode('Attack Weaker Opponents');
	is($garrison->check_for_fight($party), 0, "Doesn't attack when set to attack weaker");

	$garrison->party_attack_mode('Attack Similar Opponents');
	is($garrison->check_for_fight($party), 0, "Doesn't attack when set to attack similar");
	
	$garrison->party_attack_mode('Attack Stronger Opponents');
	is($garrison->check_for_fight($party), 1, "Attacks when set to attack stronger");       
}

sub test_check_for_fight_vs_own_party : Tests(1) {
    my $self = shift;
    
    # GIVEN
	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
	);
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => 2);
	$garrison->party_attack_mode('Attack Stronger Opponents');
	
	# WHEN / THEN
	is($garrison->check_for_fight($party), 0, "Doesn't attack own party");       
}

sub test_check_for_fight_vs_cg : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg(
		$self->{schema},
		character_count => 1,
		creature_level => 1,
	);
	my $party2 = Test::RPG::Builder::Party->build_party($self->{schema});	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 6);
	
	# WHEN / THEN
	$garrison->creature_attack_mode('Attack Weaker Opponents');
	is($garrison->check_for_fight($cg), 0, "Doesn't attack when set to attack weaker");

	$garrison->creature_attack_mode('Attack Similar Opponents');
	is($garrison->check_for_fight($cg), 1, "Attacks when set to attack similar");
	
	$garrison->creature_attack_mode('Attack Stronger Opponents');
	is($garrison->check_for_fight($cg), 1, "Attacks when set to attack stronger");       
}

sub test_check_for_fight_vs_party_from_own_kingdom : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
		kingdom_id => $kingdom->id,
	);
	my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id);	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 2);
	
	# WHEN / THEN
	is($garrison->check_for_fight($party), 0, "Doesn't attack party from own kingdom, by default");
	
	$garrison->attack_parties_from_kingdom(1);
	is($garrison->check_for_fight($party), 1, "Attacks party from own kingdom, when requested to");       
}

1;