package RPG::Combat::InWilderness;

use Mouse::Role;

requires qw/combat_log schema/;

use List::Util qw(shuffle);

sub get_sector_to_flee_to {
    my $self = shift;
    my $exclude_towns_and_cgs = shift // 0;
    
    # TODO: best way to get this?
    my $combat_location = $self->combat_log->land;
    
    my @sectors_to_flee_to = $self->schema->resultset('Land')->search_for_adjacent_sectors(
        $combat_location->x,
        $combat_location->y,
        3,
        10,
        $exclude_towns_and_cgs,
    );
    
    @sectors_to_flee_to = shuffle @sectors_to_flee_to;
    my $land = shift @sectors_to_flee_to;

    #$c->log->debug( "Fleeing to " . $land->x . ", " . $land->y );

    return $land;
}

1;