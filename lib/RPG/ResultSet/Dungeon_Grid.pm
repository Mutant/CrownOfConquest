use strict;
use warnings;

package RPG::ResultSet::Dungeon_Grid;

use base 'DBIx::Class::ResultSet';

use DBIx::Class::ResultClass::HashRefInflator;

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
            prefetch => [ { 'dungeon_room' => 'dungeon' }, { 'doors' => 'position' }, { 'walls' => 'position' } ],
        }        
    );
    
    $mapped_sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
    my @sectors = $mapped_sectors_rs->all;
    
    foreach my $sector (@sectors) {
        my @doors;
        foreach my $raw_door (@{$sector->{doors}}) {
            push @doors, $raw_door->{position}{position};
        }
        
        $sector->{raw_doors} = $sector->{doors};
        $sector->{doors} = \@doors;

        my @walls;
        foreach my $raw_wall (@{$sector->{walls}}) {
            push @walls, $raw_wall->{position}{position};
        }
        
        $sector->{raw_walls} = $sector->{walls};
        $sector->{walls} = \@walls;
    }
    
    return @sectors;
}

1;