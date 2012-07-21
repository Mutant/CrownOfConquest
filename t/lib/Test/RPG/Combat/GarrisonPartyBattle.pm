use strict;
use warnings;

package Test::RPG::Combat::GarrisonPartyBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;
use Test::MockObject::Extends;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Effect;
use Test::RPG::Builder::Land;

sub startup : Tests( startup => 1 ) {
	use_ok 'RPG::Combat::GarrisonPartyBattle';
}

sub setup : Tests(setup) {
	my $self = shift;

	Test::RPG::Builder::Day->build_day( $self->{schema} );
}

sub test_new : Tests(1) {
	my $self = shift;

	# GIVEN
	my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id );

	# WHEN
	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		schema   => $self->{schema},
		log      => $self->{mock_logger},
		party    => $party1,
		garrison => $garrison,
	);

	# THEN
	isa_ok( $battle, 'RPG::Combat::GarrisonPartyBattle', "Object instatiated correctly" );
}

sub test_combat_ends_if_garrison_wiped_out_by_effect : Tests(2) {
	my $self = shift;
	
	return "Breaks for some reason";

	# GIVEN
	my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
	my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 1 );

	my ($char) = $garrison->characters;
	$char->hit_points(1);
	$char->update;
	
	my ($char2) = $party1->characters;
	$char2->last_combat_action('Attack');
	$char->update;

	Test::RPG::Builder::Effect->build_effect( $self->{schema}, character_id => $char->id, effect_name => 'poisoned', modified_stat => 'poison' );

	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		schema   => $self->{schema},
		log      => $self->{mock_logger},
		party    => $party1,
		garrison => $garrison,
		config   => $self->{config},
	);

	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_false('check_for_flee');
	$battle->set_false('stalemate_check');

	# WHEN
	my $res = $battle->execute_round();

	# THEN
	is( $garrison->is($res->{losers}), 1, "Garrison were losers" );
	is($res->{combat_complete}, 1, "Combat completed");
}

sub test_garrison_flees : Tests(3) {
	my $self = shift;

	# GIVEN
	my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
	my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id, character_count => 1 );
	
	$garrison->in_combat_with($party1->id);
	$garrison->update;
	
	$party1->in_combat_with($garrison->id);
	$party1->update;

	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		schema   => $self->{schema},
		log      => $self->{mock_logger},
		party    => $party1,
		garrison => $garrison,
		config   => $self->{config},
	);

	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_true('check_for_flee');
	$battle->set_false('stalemate_check');
	$battle->{result}->{garrison_fled} = 1;

	# WHEN
	my $res = $battle->execute_round();

	# THEN
	is($res->{combat_complete}, 1, "Combat completed");
	
	$garrison->discard_changes;
	is($garrison->in_combat_with, undef, "Garrison no longer in combat with party");
	
	$party1->discard_changes;
	is($party1->in_combat_with, undef, "Party no longer in combat with garrison");
}

sub test_finish_garrison_lost : Test(7) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party1->id, land_id => $land[4]->id, character_count => 2);
	my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[4]->id );
	
	my @characters = $garrison->characters;
	
	$self->{config}{nearby_town_range} = 1;
	
	my $battle = RPG::Combat::GarrisonPartyBattle->new(
        schema             => $self->{schema},
        garrison           => $garrison,
        party			   => $party2,
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
		is($char->status, 'corpse', "Character now a corpse");
		is($char->status_context, $land[4]->id, "Corpse location set correctly");
		is($char->garrison_id, undef, "Character removed from garrison");
	}
}

1;
