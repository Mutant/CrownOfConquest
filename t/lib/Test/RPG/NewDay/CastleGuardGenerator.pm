use strict;
use warnings;

package Test::RPG::NewDay::CastleGuardGenerator;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureType;

sub setup : Test(setup => 1) {
    my $self = shift;

	use_ok 'RPG::NewDay::Role::CastleGuardGenerator';

    $self->setup_context;
    
}

sub shutdown : Test(shutdown) {
	my $self = shift;
}

sub test_generate_guards : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle',);
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id);
	
	my $mock = Test::MockObject->new();
	$mock->set_always('context', $self->{mock_context});
	
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 6, category_name => 'Guards');
	my $type2 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 10, category_name => 'Guards');
	
	# WHEN
	RPG::NewDay::Role::CastleGuardGenerator::generate_guards($mock, $castle);
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	cmp_ok(scalar @cgs, '>=', 1, "At least one creature group generated");
	
	my $level_aggr;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$level_aggr+=$cret->type->level;
		}			
	}
	
	my $level_aggr_expected = $town->prosperity * 15;
	cmp_ok($level_aggr, '<=', $level_aggr_expected, "Level aggregate less than or equal to town allows");
	cmp_ok($level_aggr, '>', $level_aggr_expected - 5, "Level aggreate greater than expected minus lowest guard level");
}

1;
