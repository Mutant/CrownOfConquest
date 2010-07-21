use strict;
use warnings;

package Test::RPG::Combat::MagicalDamage::Fire;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Creature;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;
use DateTime;

use RPG::Combat::MagicalDamage::Fire;

sub test_apply : Tests(9) {
	my $self = shift;
	
	# GIVEN
	$self->mock_dice;
	$self->{rolls} = [5, 5, 50, 5, 5];
	
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
	my $creature = Test::RPG::Builder::Creature->build_creature( $self->{schema}, cg_id => $cg->id, creature_hit_points_current => 10 );
	
	# WHEN
	my $magical_damage_result = RPG::Combat::MagicalDamage::Fire->apply(
		character => $character,
		opponent => $creature,
		opponent_group => $cg,
		level => 2,		
	);
	
	# THEN
	isa_ok($magical_damage_result, 'RPG::Combat::MagicalDamageResult', "Returned object is of correct type");	
	is($magical_damage_result->resisted, 0, "Opponent didn't resist");
	is($magical_damage_result->extra_damage, 7, "Extra damage recorded correctly");
	
	$creature->discard_changes;
	is($creature->hit_points_current, 3, "Creature took fire damage");
	
	my $others = $magical_damage_result->other_damages;
	
	is(scalar @$others, 1, "One other creature damaged");
	isa_ok($others->[0], 'RPG::Combat::ActionResult', "Other damages is of correct type");
	
	my ($other_creature) = grep { $_->id != $creature->id } $cg->creatures;
	
	is($others->[0]->defender->id, $other_creature->id, "Correct creature attacked with secondary damage");
	is($others->[0]->magical_damage->extra_damage, 5, "Correct extra damage dealt to creatures");
	$other_creature->discard_changes;
	is($other_creature->hit_points_current, 0, "Damage dealt to other creature");

}

1;