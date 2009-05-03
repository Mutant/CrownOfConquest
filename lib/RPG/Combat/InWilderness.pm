package RPG::Combat::InWilderness;

use Moose::Role;

# Can't require these as they're attributes, not methods (missing Moose functionality?)
#requires qw/schema creature_group party/;

use List::Util qw(shuffle);

has 'location' => ( is => 'ro', isa => 'RPG::Schema::Land', required => 0, builder => '_build_location', lazy => 1, );

sub get_sector_to_flee_to {
    my $self = shift;
    my $exclude_towns_and_cgs = shift // 0;

    my @sectors_to_flee_to =
        $self->schema->resultset('Land')->search_for_adjacent_sectors( $self->location->x, $self->location->y, 3, 10, $exclude_towns_and_cgs, );

    @sectors_to_flee_to = shuffle @sectors_to_flee_to;
    my $land = shift @sectors_to_flee_to;

    $self->log->debug( "Fleeing to " . $land->x . ", " . $land->y );

    return $land;
}

# TODO: these shouldn't be here?
sub creatures_flee_to {
    my $self = shift;
    my $land = shift;

    $self->creature_group->land_id( $land->id );
    $self->creature_group->update;
}

sub party_flees_to {
    my $self = shift;
    my $land = shift;

    $self->party->land_id( $land->id );
    $self->party->in_combat_with(undef);
    
    # Still costs them turns to move (but they can do it even if they don't have enough turns left)
    $self->party->turns( $self->party->turns - $land->movement_cost( $self->party->movement_factor ) );
    $self->party->turns(0) if $self->party->turns < 0;    
}

sub _build_location {
    my $self = shift;

    return $self->party->location;
}

1;
