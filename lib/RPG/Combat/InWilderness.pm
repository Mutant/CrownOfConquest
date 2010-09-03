package RPG::Combat::InWilderness;

use Moose::Role;

use RPG::Template;

use List::Util qw(shuffle);

# Can't require these as they're attributes, not methods (missing Moose functionality?)
#requires qw/schema creature_group party/;
requires qw/opponents/;

has 'nearby_towns' => ( is => 'ro', isa => 'ArrayRef', init_arg => undef, builder => '_build_nearby_towns', lazy => 1, auto_deref => 1 );
has 'location' => ( is => 'ro', isa => 'RPG::Schema::Land', required => 0, builder => '_build_location', lazy => 1, );

sub get_sector_to_flee_to {
    my $self = shift;
    my $fleeing_group = shift;
    
    my $exclude_towns_and_cgs = $fleeing_group->group_type eq 'creature_group' ? 1 : 0;

    my @sectors_to_flee_to =
        $self->schema->resultset('Land')->search_for_adjacent_sectors( $self->location->x, $self->location->y, 3, 10, $exclude_towns_and_cgs, );

    @sectors_to_flee_to = shuffle @sectors_to_flee_to;
    my $land = shift @sectors_to_flee_to;

    $self->log->debug( "Fleeing to " . $land->x . ", " . $land->y );

    return $land;
}

sub _build_location {
    my $self = shift;

    foreach my $opponent ( $self->opponents ) {
    	return $opponent->current_location;
    }
}

sub _build_nearby_towns {
    my $self = shift;
    
    my @towns = $self->schema->resultset('Town')->find_in_range(
        {
            x => $self->location->x,
            y => $self->location->y,
        },
        $self->config->{nearby_town_range},
    );
    
    return \@towns;
}

after 'finish' => sub {
    my $self = shift;
    
    if (defined @{$self->nearby_towns}) {
        my $message = RPG::Template->process( $self->config, 'combat/town_news_message.html', { log => $self->combat_log, }, );

        my $day_id = $self->schema->resultset('Day')->find_today->id;

        foreach my $town ($self->nearby_towns) {
            $self->schema->resultset('Town_History')->create(
                {
                    town_id => $town->id,
                    day_id  => $day_id,
                    message => $message,
                }
            );
        }
    }
};

sub combat_log_location_attribute {
    return 'land_id';   
}

1;
