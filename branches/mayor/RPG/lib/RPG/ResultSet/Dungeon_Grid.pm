use strict;
use warnings;

package RPG::ResultSet::Dungeon_Grid;

use base 'DBIx::Class::ResultSet';

use DBIx::Class::ResultClass::HashRefInflator;

use Data::Dumper;

# Get a dungeon grid... range is optional. If party_id is supplied, only returns sectors in that party's mapped_dungeon_grid
sub get_party_grid {
	my $self       = shift;
	my $party_id   = shift;
	my $dungeon_id = shift;
	my $range      = shift;

	my %params = (
		'dungeon.dungeon_id' => $dungeon_id,
	);

	my @join;

	if ( defined $party_id ) {
		$params{party_id} = $party_id;
		@join = ('mapped_dungeon_grid');
	}

	if ($range) {
		$params{x} = { '>=', $range->{top_corner}{x}, '<=', $range->{bottom_corner}{x} };
		$params{y} = { '>=', $range->{top_corner}{y}, '<=', $range->{bottom_corner}{y} };
	}

	my $mapped_sectors_rs = $self->search(
		\%params,
		{
			join     => \@join,
			prefetch => [ { 'dungeon_room' => 'dungeon' }, { 'doors' => 'position' }, { 'walls' => 'position' }, 'treasure_chest' ],
		}
	);

	$mapped_sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

	my @sectors = $mapped_sectors_rs->all;

	foreach my $sector (@sectors) {
		my @walls;
		foreach my $raw_wall ( @{ $sector->{walls} } ) {
			push @walls, $raw_wall->{position}{position};
		}

		$sector->{raw_walls}        = $sector->{walls};
		$sector->{sides_with_walls} = \@walls;
	}

	return @sectors;
}

sub find_random_sector {
	my $self            = shift;
	my $dungeon_id      = shift;
	my $dungeon_room_id = shift;
	my $no_cg_in_sector = shift // 0;
	
	my %params = (
		'dungeon_room.dungeon_id' => $dungeon_id,
	);
	
	if ($dungeon_room_id) {
		$params{'dungeon_room.dungeon_room_id'} = $dungeon_room_id;	
	}
	
	if ($no_cg_in_sector) {
		$params{'creature_group.creature_id'} = undef;	
	}

	$self->find(
		\%params,
		{
			order_by => 'rand()',
			rows     => 1,
			join     => 'dungeon_room',
			prefetch => 'creature_group',
		}
	);
}

1;
