package RPG::Combat::InDungeon;

use Moose::Role;

use List::Util qw(shuffle);
use RPG::Map;

has 'location' => ( is => 'ro', isa => 'RPG::Schema::Dungeon_Grid', required => 0, builder => '_build_location', lazy => 1, );

sub get_sector_to_flee_to {
    my $self = shift;
    my $fleeing_group = shift;
    
    my $exclude_creatures = $fleeing_group->group_type eq 'creature_group' ? 1 : 0;    
    
    my $sector = $fleeing_group->dungeon_grid;
    my $flee_sector;
    
    my $range = 1;
    my $consider_doors = $fleeing_group->group_type eq 'creature_group' ? 0 : 1;
    
    OUTER: while (my $allowed_sectors = $sector->sectors_allowed_to_move_to( $range, $consider_doors ) ) {
        foreach my $sector_id (shuffle keys %$allowed_sectors) {
            next unless $allowed_sectors->{$sector_id};
            
            $flee_sector = $self->schema->resultset('Dungeon_Grid')->find( { dungeon_grid_id => $sector_id, } );
            
            next if $exclude_creatures && $flee_sector->creature_group;
            
            last OUTER;
        }        
        
        $range++;
        last if $range >= 5;
    }    

    confess "Couldn't find land to flee to: (fleeing group: " . ref($fleeing_group) . ", id: " . $fleeing_group->id . ")"  unless $flee_sector;

    $self->log->debug( "Fleeing to " . $flee_sector->x . ", " . $flee_sector->y );

    return $flee_sector;
}

sub _build_location {
    my $self = shift;

    return $self->schema->resultset('Dungeon_Grid')->find( { dungeon_grid_id => $self->party->dungeon_grid_id, } );
}

sub combat_log_location_attribute {
    return 'dungeon_grid_id';   
}

1;
