use strict;
use warnings;

package RPG::ResultSet::Dungeon_Grid;

use base 'DBIx::Class::ResultSet';

use DBIx::Class::ResultClass::HashRefInflator;

use Data::Dumper;

# Get a dungeon grid... range is optional. If party_id is supplied, only returns sectors in that party's mapped_dungeon_grid
sub get_party_grid {
    my $self = shift;
    my $party_id = shift;
    my $dungeon_id = shift;
    my $range = shift;

	my %params = (
        'dungeon.dungeon_id' => $dungeon_id,
	);
	
	my @join;

	if (defined $party_id) {
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
        	join => \@join,
            prefetch => [ { 'dungeon_room' => 'dungeon' }, { 'doors' => 'position' }, { 'walls' => 'position' }, 'treasure_chest' ],
        }        
    );
    
    $mapped_sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
    my @sectors = $mapped_sectors_rs->all;
    
    foreach my $sector (@sectors) {
        my @walls;
        foreach my $raw_wall (@{$sector->{walls}}) {
            push @walls, $raw_wall->{position}{position};
        }
        
        $sector->{raw_walls} = $sector->{walls};
        $sector->{sides_with_walls} = \@walls;
    }
    
    return @sectors;
}

1;