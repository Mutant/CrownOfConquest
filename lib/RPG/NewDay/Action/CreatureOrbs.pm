package RPG::NewDay::Action::CreatureOrbs;
use Moose;

extends 'RPG::NewDay::Base';

use RPG::Map;
use RPG::Maths;
use List::Util qw(shuffle);
use File::Slurp qw(read_file);

sub cron_string {
    my $self = shift;

    return $self->context->config->{creature_orb_cron_string};
}

sub run {
    my $self = shift;

    $self->spawn_orbs;

    $self->spawn_town_orbs;
}

# Every town has at least one level 1 orb nearby
sub spawn_town_orbs {
    my $self = shift;

    my $c = $self->context;

    $c->logger->info("Creating Orbs near towns");

    my $town_rs = $c->schema->resultset('Town')->search( {}, { prefetch => 'location', } );

    $town_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    while ( my $town = $town_rs->next ) {
        my ( $start_point, $end_point ) = RPG::Map->surrounds_by_range( $town->{location}{x}, $town->{location}{y}, 5 );

        my $orb_in_range = 0;

        for my $x ( $start_point->{x} .. $end_point->{x} ) {
            for my $y ( $start_point->{y} .. $end_point->{y} ) {

                my $sector = $c->land_grid->get_land_at_location( $x, $y );

                if ( $sector->{orb} ) {
                    $orb_in_range = 1;
                    last;
                }
            }
        }

        if ( !$orb_in_range ) {
            $c->logger->info( "Orb needed near town " . $town->{town_name} . " at " . $town->{location}{x} . ", " . $town->{location}{y} );

            my $created = $self->_create_orb_in_land( 1, $start_point, $end_point );

            unless ($created) {
                $c->logger->warning( "Couldn't create orb near " . $town->{town_name} . " as no suitable land could be found" );
            }
        }
    }
}

sub spawn_orbs {
    my $self = shift;
    my $c    = $self->context;

    my $land_size = $c->schema->resultset('Land')->search->count;

    my $ideal_number_of_orbs = int $land_size / $c->config->{land_per_orb};

    my $orbs_to_create = $ideal_number_of_orbs - $c->schema->resultset('Creature_Orb')->count( land_id => { '!=', undef } );

    return if $orbs_to_create <= 0;
    $c->logger->info("Creating $orbs_to_create orbs");

    for my $orb_number ( 1 .. $orbs_to_create ) {
        my $level = RPG::Maths->weighted_random_number( 1 .. $c->config->{max_orb_level} );

        $c->logger->debug("Creating orb # $orb_number (level: $level)");

        my $created = $self->_create_orb_in_land( $level, { x => 1, y => 1 }, { x => $c->land_grid->max_x, y => $c->land_grid->max_y } );

        unless ($created) {

            # Warn that we weren't able to create an orb
            $c->logger->warning("Unable to create orb # $orb_number, as no suitable land could be found");
        }

    }
}

sub _create_orb_in_land {
    my $self        = shift;
    my $c           = $self->context;
    my $level       = shift;
    my $start_point = shift;
    my $end_point   = shift;

    my $created = 0;

    my @sectors = $c->land_grid->get_sectors_within_range( $start_point, $end_point );

  OUTER: foreach my $land ( shuffle @sectors ) {

        #warn Dumper $land;
        my ( $x, $y ) = ( $land->{x}, $land->{y} );

        next if $land->{orb} || $land->{town} || $land->{garrison};

        next if $land->{ctr} < ( $level * 50 ) - 125;

        # Search for towns and orbs in this sector to see if it will block us spawning the orb.
        # The two searches are different sizes, so we have to find the largest one

        my @town_range = RPG::Map->surrounds_by_range( $x, $y, $c->config->{orb_distance_from_town_per_level} );
        my @orb_range = RPG::Map->surrounds_by_range( $x, $y, $c->config->{orb_distance_from_other_orb} );

        my @range;
        if ( $c->config->{orb_distance_from_town_per_level} > $c->config->{orb_distance_from_other_orb} ) {
            @range = @town_range;
        }
        else {
            @range = @orb_range;
        }

        for my $x_to_check ( $range[0]->{x} .. $range[1]->{x} ) {
            for my $y_to_check ( $range[0]->{y} .. $range[1]->{y} ) {

                #warn "Checking surround sector: $x_to_check, $y_to_check";
                my $sector_to_check = $c->land_grid->get_land_at_location( $x_to_check, $y_to_check );

                next unless $sector_to_check;

                # Orb must be minium range from town
                if ( $x_to_check >= $town_range[0]->{x}
                    && $x_to_check <= $town_range[1]->{x}
                    && $y_to_check >= $town_range[0]->{y}
                    && $y_to_check <= $town_range[1]->{y} )
                {
                    next OUTER if $sector_to_check->{town};
                }

                # Check for orbs
                if ( $x_to_check >= $orb_range[0]->{x}
                    && $x_to_check <= $orb_range[1]->{x}
                    && $y_to_check >= $orb_range[0]->{y}
                    && $y_to_check <= $orb_range[1]->{y} )
                {
                    next OUTER if $sector_to_check->{orb};
                }
            }
        }

        # No towns in range, and no existing orb here... we can use this sector
        $self->_spawn_orb( $land, $level );

        $c->land_grid->set_land_object( 'orb', $x, $y, );

        $created = 1;

        last;
    }

    return $created;
}

my @names;

sub _spawn_orb {
    my $self  = shift;
    my $c     = $self->context;
    my $land  = shift;
    my $level = shift;

    unless (@names) {
        @names = read_file( $ENV{RPG_HOME} . '/script/data/orb_names.txt' );
        chomp @names;
    }

    $c->logger->debug("Spawning Orb at $land->{x}, $land->{y}");

    my $name;

    # Choose an Orb name (so long as they don't already exist)
    foreach my $name_to_check ( shuffle @names ) {
        my $existing_orb = $c->schema->resultset('Creature_Orb')->find( { name => $name_to_check, land_id => { '!=', undef } } );

        next if $existing_orb;

        $name = $name_to_check;
    }

    my $land_record = $c->schema->resultset('Land')->find(
        {
            x => $land->{x},
            y => $land->{y},
        },
        { prefetch => 'creature_group', },
    );

    $c->schema->resultset('Creature_Orb')->create(
        {
            land_id => $land_record->id,
            level   => $level,
            name    => $name
        }
    );

    # Create creature group at orb
    $c->schema->resultset('CreatureGroup')->create_in_wilderness( $land_record, $level * 3, $level * 3 );

    $c->land_grid->set_land_object( 'creature_group', $land->{x}, $land->{y} );
}

__PACKAGE__->meta->make_immutable;

1;
