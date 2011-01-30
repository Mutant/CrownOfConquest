use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::Paths;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;

use Test::More;
use Test::MockObject::Extends;

sub startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::NewDay::Action::Dungeon');

	$self->setup_context;	
}

sub setup : Tests(setup) {
    my $self = shift;
    
    RPG::NewDay::Action::Dungeon::_clear_item_type_by_prevalence();    
}

sub test_fill_chest : Tests(1) {
	my $self = shift;
	
	# GIVEN
	my $chest = Test::RPG::Builder::Treasure_Chest->build_chest($self->{schema});
	$chest = Test::MockObject::Extends->new($chest);
	$chest->set_always('dungeon_grid', $chest);
	$chest->set_always('dungeon_room', $chest);
	$chest->set_always('dungeon', $chest);
	$chest->set_always('level', 1);
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type($self->{schema});
	
	my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );
	
	$self->mock_dice;
	$self->{rolls} = ['50', '1', '1', '1'];
	
    my $maths = Test::MockObject::Extra->new();

	my $math_results = [1,0];
    $maths->fake_module(
    	'RPG::Maths',
    	weighted_random_number => sub { shift @$math_results },
    );
	
	# WHEN
	$action->fill_chest($chest);
	
	# THEN
	my @items = $chest->items;
	is(scalar @items, 1, "1 item created in chest");
	
	$self->unmock_dice;
	$maths->unfake_module;
	$SIG{__WARN__} = sub {
		my ($msg) = @_;
		
		return if $msg =~ /Subroutine (\S+) redefined/;
		
		print STDERR $msg;
	};
	require RPG::Maths;
}

sub test_fill_empty_chests : Tests() {
	my $self = shift;
	
	# GIVEN		
	my @chests;
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
	   dungeon_id => $dungeon->id,
	   top_left => {x => 1, y => 1},
	   bottom_right => {x => 5, y => 5}, 
	);
	
	my @sectors = $room->sectors;
	
	for my $idx (1..5) {
    	my $chest = Test::RPG::Builder::Treasure_Chest->build_chest($self->{schema}, dungeon_grid_id => $sectors[$idx]->id);
    	
    	push @chests, $chest;
	}
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type($self->{schema});
	
	my $item1 = Test::RPG::Builder::Item->build_item($self->{schema}, treasure_chest_id => $chests[2]->id, item_type_id => $item_type->id);		
	my $item2 = Test::RPG::Builder::Item->build_item($self->{schema}, treasure_chest_id => $chests[4]->id, item_type_id => $item_type->id);
	
	my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );
	
	$self->{config}{empty_chest_fill_chance} = 100;
	
	# WHEN
	$action->fill_empty_chests;
	
	# THEN
	my $count = 0;
	foreach my $chest (@chests) {
	   $chest->discard_changes;
	   
	   my @items = $chest->items;

	   is($chest->is_empty, 0, "Chest $count is not empty");
	   if ($count == 2 || $count == 4) {
	       is(scalar @items, 1, "Only 1 item in chest $count, as it wasn't empty");   
	   }
	   else {
	       cmp_ok(scalar @items, '>=', 1, "1 or more items added to chest $count");
	       cmp_ok(scalar @items, '<=', 3, "3 or more items added to chest $count");
	   }
	   
	   $count++;
	}
	
	
}

1;