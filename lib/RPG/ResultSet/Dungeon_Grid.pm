use strict;
use warnings;

package RPG::ResultSet::Dungeon_Grid;

use base 'DBIx::Class::ResultSet';

use DBIx::Class::ResultClass::HashRefInflator;

use Data::Dumper;

sub get_party_grid {
    my $self = shift;
    my $party_id = shift;
    my $dungeon_id = shift;
    
    my $mapped_sectors_rs = $self->search(
        {
            party_id             => $party_id,
            'dungeon.dungeon_id' => $dungeon_id,
        },
        {
            join     => 'mapped_dungeon_grid',
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