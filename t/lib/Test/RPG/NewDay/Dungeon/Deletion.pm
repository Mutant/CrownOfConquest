use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::Deletion;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;
use Data::Dumper;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Party;


sub startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::NewDay::Action::Dungeon');
	
	$self->setup_context;	
}

sub test_check_for_dungeon_deletion : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
		dungeon_id => $dungeon->id, 
		top_left => {x=>1, y=>1},
		bottom_right => {x=>3, y=>3},
	);
	my @sectors = $room1->sectors;
	
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, dungeon_grid_id => $sectors[0]->id, land_id => $dungeon->land_id);
	
	my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );
	
	$self->mock_dice;
	$self->{roll_result} = 1;
	
	# WHEN
	$action->check_for_dungeon_deletion();	
	
	# THEN
	$dungeon->discard_changes;
	is($dungeon->in_storage, 0, "Dungeon deleted");
	
	$party->discard_changes;
	is($party->dungeon_grid_id, undef, "Party returned to surface");
	
	is($party->messages->count, 1, "1 message added to party");	
	
	$self->unmock_dice;
    
}