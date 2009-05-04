package RPG::Combat::InWilderness;

use Moose::Role;

# Can't require these as they're attributes, not methods (missing Moose functionality?)
#requires qw/schema creature_group party/;
requires qw/opponents/;

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

sub _build_location {
    my $self = shift;

    foreach my $opponent ($self->opponents) {
        if ($opponent->isa('RPG::Schema::Party')) {
            return $opponent->location;
        }
    }
}

1;
