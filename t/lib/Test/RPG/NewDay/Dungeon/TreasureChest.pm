use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::Paths;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Item_Type;

use Test::More;
use Test::MockObject::Extends;

sub startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::NewDay::Action::Dungeon');
	
	$self->setup_context;	
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

1;