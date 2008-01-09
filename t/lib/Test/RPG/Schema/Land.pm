use strict;
use warnings;

package Test::RPG::Schema::Land;

use base qw(Test::RPG);

use Test::More;
use Test::MockObject;

use RPG::Schema::Land;

sub test_next_to : Tests(5) {
	my $self = shift;
	
	my @tests = (
		{
			sectors => [
				{x => 1, y => 2},
				{x => 3, y => 4},
			],
			result => 0,
			desc => 'Sectors not next to each other',
		},
		{
			sectors => [
				{x => 1, y => 1},
				{x => 1, y => 2},
			],
			result => 1,
			desc => 'Sector to the right',
		},
		{
			sectors => [
				{x => 100, y => 100},
				{x => 101, y => 100},
			],
			result => 1,
			desc => 'Sector below',
		},
		{
			sectors => [
				{x => 1, y => 1},
				{x => 2, y => 2},
			],
			result => 1,
			desc => 'Sector on the diagonal',
		},
		{
			sectors => [
				{x => 5, y => 5},
				{x => 5, y => 5},
			],
			result => 0,
			desc => 'Sectors the same, not next to',
		},
	);
	
	foreach my $test (@tests) {
		my @sectors;
		
		foreach my $sector (@{$test->{sectors}}) {
			my $mock_sector = Test::MockObject->new;
			$mock_sector->set_always('x', $sector->{x});
			$mock_sector->set_always('y', $sector->{y});
			push @sectors, $mock_sector;
		}
			
		is(RPG::Schema::Land::next_to(@sectors), $test->{result}, $test->{desc});
	}
}

sub test_movement_cost : Tests(1) {
	my $self = shift;
	
	my @tests = (
		{
			modifier => 5,
			movement_cost => 10,
			result => 15,
			desc => 'basic test',
		},
	);
	
	foreach my $test (@tests) {
		my $mock_terrain = Test::MockObject->new;
		$mock_terrain->set_always('modifier', $test->{modifier});
	
		my $mock_sector = Test::MockObject->new;
		$mock_sector->set_always('terrain', $mock_terrain);
		
		is(RPG::Schema::Land::movement_cost($mock_sector, $test->{movement_cost}), $test->{result}, "movement_cost: " . $test->{desc});
	}
}

1;