use strict;
use warnings;

package RPG::Ticker;

use Carp;

use RPG::Schema;
use RPG::Map;
use RPG::Maths;

use YAML;
use Data::Dumper;
use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;
use File::Slurp qw(read_file);
use Math::Round qw(round);
use Proc::PID::File;

# See note in spawn_orbs() below for details on this
my $used = [];

sub run {
    my $package = shift;

    my $home = $ENV{RPG_HOME};

    die "Already running!\n" if Proc::PID::File->running(
        dir    => "$home/proc",
        verify => 1,
    );

    my $config = YAML::LoadFile("$home/rpg.yml");
    if ( -f "$home/rpg_local.yml" ) {
        my $local_config = YAML::LoadFile("$home/rpg_local.yml");
        $config = { %$config, %$local_config };
    }

    my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . '] ' . $_[1] . "\n" } );
    $logger->add(
        Log::Dispatch::File::Stamped->new(
            name      => 'file1',
            min_level => 'debug',
            filename  => $config->{log_file_dir} . 'ticker.log',
            mode      => 'append',
            stamp_fmt => '%Y%m%d',
        ),
    );

    $logger->info('Ticker script beginning');

    eval {
        my $schema = RPG::Schema->connect( $config, @{ $config->{'Model::DBIC'}{connect_info} }, );

        # Clean up
        $package->clean_up( $config, $schema, $logger );

        # Spawn orbs
        $package->spawn_orbs( $config, $schema, $logger );

        # Spawn town orbs
        $package->spawn_town_orbs( $config, $schema, $logger );

        # Spawn monsters
        $package->spawn_monsters( $config, $schema, $logger );

        # Move monsters
        $package->move_monsters( $config, $schema, $logger );

        $schema->storage->dbh->commit unless $schema->storage->dbh->{AutoCommit};
    };
    if ($@) {
        $logger->error("Error running ticker script: $@");
    }

    $logger->info('Ticker script ended');
}

# Every town has at least one level 1 orb nearby
sub spawn_town_orbs {
    my ( $package, $config, $schema, $logger ) = @_;
    
    $logger->info("Creating Orbs near towns");

    my @towns = $schema->resultset('Town')->search( {}, { prefetch => 'location', } );

    foreach my $town (@towns) {
        my @range = RPG::Map->surrounds( $town->location->x, $town->location->y, 17, 17 );
        
        my @sectors = $schema->resultset('Land')->search(
            {
                'x' => { '>=', $range[0]->{x}, '<=', $range[1]->{x} },
                'y' => { '>=', $range[0]->{y}, '<=', $range[1]->{y} },
            },
            { prefetch => ['orb'], }
        );

        my $orb_in_range;

        foreach my $sector (@sectors) {

            # Only check sectors 5 away from the town. We load in a few more because they're needed in creating the orb
            # (to make sure we don't create the orb too close to a town or another orb)
            my $distance = RPG::Map->get_distance_between_points(
                {
                    x => $town->location->x,
                    y => $town->location->y,
                },
                {
                    x => $sector->x,
                    y => $sector->y,
                }
            );
                        
            next if $distance > 4;
            

            if ( $sector->orb ) {
                $orb_in_range = 1;
                last;
            }
        }

        if ( !$orb_in_range ) {
            $logger->info("Orb needed near town " . $town->town_name . " at " . $town->location->x . ", " . $town->location->y);
            
            my $created = $package->_create_orb_in_land( $config, $schema, $logger, 1, @sectors );
            
            unless ($created) {
                $logger->warning("Couldn't create orb near " . $town->town_name . " as no suitable land could be found");
            }
        }
    }
}

sub spawn_orbs {
    my ( $package, $config, $schema, $logger ) = @_;

    # Bit hacky, but we have the $used package variable that keeps track of where orbs are spawned. This is done as an optimisation,
    #  as we don't want to go back to the DB to check for orbs we've created during this session. Clear it here to be sure
    undef $used;

    my $land_size = $schema->resultset('Land')->search->count;

    my $ideal_number_of_orbs = int $land_size / $config->{land_per_orb};

    my $orbs_to_create = $ideal_number_of_orbs - $schema->resultset('Creature_Orb')->count( land_id => {'!=', undef} );

    $logger->info("Creating $orbs_to_create orbs");

    return if $orbs_to_create <= 0;

    my @land = $schema->resultset('Land')->search(
        {},
        {
            order_by => 'rand()',
            prefetch => [ 'town', 'orb' ],
        }
    );

    for my $orb_number ( 1 .. $orbs_to_create ) {
        my $level = RPG::Maths->weighted_random_number( 1 .. $config->{max_orb_level} );

        $logger->debug("Creating orb # $orb_number (level: $level)");

        my $created = $package->_create_orb_in_land( $config, $schema, $logger, $level, @land );

        unless ($created) {

            # Warn that we weren't able to create an orb
            $logger->warning("Unable to create orb # $orb_number, as no suitable land could be found");
        }

    }
}

sub spawn_monsters {
    my ( $package, $config, $schema, $logger ) = @_;

    my $number_of_groups_to_spawn = $package->_calculate_number_of_groups_to_spawn( $config, $schema );

    $logger->info("Spawning $number_of_groups_to_spawn monsters");

    return if $number_of_groups_to_spawn <= 0;

    my @creature_orbs = $schema->resultset('Creature_Orb')->search( {}, { prefetch => 'land', land_id => {'!=', undef} } );

    my %orb_surrounds;

    my $level_rs = $schema->resultset('CreatureType')->find(
        {},
        {
            select => [              { max => 'level' }, { min => 'level' }, ],
            as     => [ 'max_level', 'min_level' ],
        }
    );

    # Spawn random groups
    my $spawned = {};

    for my $group_number ( 1 .. $number_of_groups_to_spawn ) {

        # Pick an orb to spawn near

        @creature_orbs = shuffle @creature_orbs;
        my $creature_orb = $creature_orbs[0];

        my $land;

        while ( !$land ) {

            # See if any of the sectors loaded around this orb are free
            my $count = 0;
            foreach my $possible_sector ( @{ $orb_surrounds{ $creature_orb->id }{sectors} } ) {
                if ( !$spawned->{ $possible_sector->x }{ $possible_sector->y } && !$possible_sector->creature_group && !$possible_sector->town ) {
                    $land = $possible_sector;

                    # Record where we've spawned creatures, so we don't have to re-read everything
                    $spawned->{ $possible_sector->x }{ $possible_sector->y } = 1;

                    last;
                }

                $count++;
            }

            # Load in more sectors to check if we couldn't find a suitable one
            unless ($land) {

                # Load in some sectors to check
                if ( $orb_surrounds{ $creature_orb->id }{size} ) {
                    $orb_surrounds{ $creature_orb->id }{size} += 2;
                }
                else {
                    $orb_surrounds{ $creature_orb->id }{size} = 1;
                }

                my $size_to_get = $orb_surrounds{ $creature_orb->id }{size};

                my @range = RPG::Map->surrounds( $creature_orb->land->x, $creature_orb->land->y, $size_to_get, $size_to_get );

                # Somewhat ineffecient, as we'll look thru a lot of sectors multiple times...
                my @sectors = $schema->resultset('Land')->search(
                    {
                        'x' => { '>=', $range[0]->{x}, '<=', $range[1]->{x} },
                        'y' => { '>=', $range[0]->{y}, '<=', $range[1]->{y} },
                    },
                    { prefetch => [ 'creature_group', 'town' ], }
                );

                $orb_surrounds{ $creature_orb->id }{sectors} = \@sectors;
            }
        }

        my $level = RPG::Maths->weighted_random_number( 1 .. $creature_orb->level * 3 );

        $package->_create_group( $schema, $land, $level, $level );

        if ( $group_number % 100 == 0 ) {
            $logger->info("Spawned $group_number groups...");
        }
    }
}

sub _calculate_number_of_groups_to_spawn {
    my ( $package, $config, $schema ) = @_;

    # Calculate how many creature groups we should spawn
    my $number_of_parties = $schema->resultset('Party')->search->count;

    my $number_of_creature_groups = $schema->resultset('CreatureGroup')->search( { land_id => { '!=', undef }, } )->count;

    my $size_of_world = $schema->resultset('Land')->search->count;

    my $ideal_groups = $number_of_parties * $config->{creature_groups_to_parties};

    if ( $ideal_groups > $size_of_world * $config->{max_creature_groups_per_sector} ) {
        $ideal_groups = $size_of_world * $config->{max_creature_groups_per_sector};
    }
    elsif ( $ideal_groups < $size_of_world * $config->{min_creature_groups_per_sector} ) {
        $ideal_groups = $size_of_world * $config->{min_creature_groups_per_sector};
    }

    # We don't remove groups if we're over the max
    my $number_of_groups_to_spawn = 0;
    if ( $ideal_groups > $number_of_creature_groups ) {
        $number_of_groups_to_spawn = $ideal_groups - $number_of_creature_groups;
    }

    #warn "Spawning: $number_of_groups_to_spawn\n";

    return $number_of_groups_to_spawn;
}

my @creature_types;

sub _create_group {
    my ( $package, $schema, $land, $min_level, $max_level ) = @_;

    @creature_types = $schema->resultset('CreatureType')->search()
        unless @creature_types;

    my $cg = $schema->resultset('CreatureGroup')->create( { land_id => $land->id, } );

    my $type;
    foreach my $type_to_check ( shuffle @creature_types ) {
        next if $type_to_check->level > $max_level || $type_to_check->level < $min_level;
        $type = $type_to_check;
        last;
    }

    confess "Couldn't find a type for min level: $min_level, max level: $max_level\n" unless $type;

    my $number = int( rand 7 ) + 3;

    for my $creature ( 1 .. $number ) {
        my $hps = Games::Dice::Advanced->roll( $type->level . 'd8' );

        $schema->resultset('Creature')->create(
            {
                creature_type_id   => $type->id,
                creature_group_id  => $cg->id,
                hit_points_current => $hps,
                hit_points_max     => $hps,
                group_order        => $creature,
            }
        );
    }

    $land->creature_threat( $land->creature_threat + 5 );
    $land->update;

    return $cg;
}

my %cant_move_reason;

sub move_monsters {
    my ( $package, $config, $schema, $logger ) = @_;

    my @cgs_to_move = $schema->resultset('CreatureGroup')->search(
        { 'location.land_id' => { '!=', undef }, },
        { prefetch => [ { 'location' => 'orb', }, { 'creatures' => 'type' }, 'in_combat_with' ], },
    );

    my $cg_count = scalar @cgs_to_move;

    $logger->info("Moving monsters ($cg_count available)");

    my $moved           = 0;
    my $attempted_moves = 0;
    my $retries         = 0;

    while (@cgs_to_move) {
        $attempted_moves++;

        if ( $attempted_moves > $cg_count * 2 ) {

            # Stop trying to move cgs after a while...
            last;
        }

        my $cg = shift @cgs_to_move;

        my $cg_moved = 0;

        # Don't move creatures in combat, or guarding an orb
        next if $cg->in_combat_with || $cg->location->orb;

        next if Games::Dice::Advanced->roll('1d100') > $config->{creature_move_chance};

        # Find sector to move to.. try sectors immediately adjacent first, and then go one more sector if we can't find anything
        my @sizes = map { $_ + 2 } 1 .. $config->{max_hops};
        for my $size (@sizes) {
            $cg_moved = $package->_move_cg( $schema, $size, $cg );

            if ($cg_moved) {
                $moved++;

                if ( $moved % 100 == 0 ) {
                    $logger->info("Moved $moved so far...");
                }

                last;
            }
        }
        unless ($cg_moved) {

            # Couldn't move this CG. Add it back into the array and try again later
            #  (After other cg's have moved and possibly cleared some space)
            $retries++;
            push @cgs_to_move, $cg;
        }
    }

    $logger->info("Moved $moved groups ($retries retries)");

    $logger->debug( Dumper \%cant_move_reason );
}

# Clean up any dead monster groups. These sometimes get created due to bugs
# In an ideal world (or at least one with transactions) this wouldn't be needed.
# We don't delete them, since the news needs to display them
sub clean_up {
    my ( $package, $config, $schema, $logger ) = @_;

    my $cg_rs = $schema->resultset('CreatureGroup')->search( { land_id => { '!=', undef }, }, {} );

    while ( my $cg = $cg_rs->next ) {
        if ( $cg->number_alive <= 0 ) {
            $cg->land_id(undef);
            $cg->update;
        }
    }
}

sub _move_cg {
    my $package = shift;
    my $schema  = shift;
    my $size    = shift;
    my $cg      = shift;

    my $cg_moved = 0;

    my @range = RPG::Map->surrounds( $cg->location->x, $cg->location->y, $size, $size );
    my @sectors = $schema->resultset('Land')->search(
        {
            'x' => { '>=', $range[0]->{x}, '<=', $range[1]->{x} },
            'y' => { '>=', $range[0]->{y}, '<=', $range[1]->{y} },
        },
        { prefetch => [ 'creature_group', 'town' ], }
    );

    foreach my $sector ( shuffle @sectors ) {

        # Can't move to a town or sector that already has a creature group
        if ( !$sector->town && !$sector->creature_group && ( ( $sector->creature_threat / 10 ) + 1 ) > $cg->level ) {
            $cg->land_id( $sector->id );
            $cg->update;

            $sector->creature_threat( $sector->creature_threat + 1 );
            $sector->update;

            $cg_moved = 1;

            last;
        }
        else {
            $cant_move_reason{town}++, next if $sector->town;
            $cant_move_reason{cg}++,   next if $sector->creature_group;
            $cant_move_reason{ctr}++;
        }
    }

    return $cg_moved;
}

sub _create_orb_in_land {
    my $package = shift;
    my $config  = shift;
    my $schema  = shift;
    my $logger  = shift;
    my $level   = shift;
    my @land    = @_;

    my $land_by_sector;
    foreach my $sector (@land) {
        $land_by_sector->[ $sector->x ][ $sector->y ] = $sector;
    }

    my %x_y_range = $schema->resultset('Land')->get_x_y_range();

    my $created = 0;

    OUTER: foreach my $land (@land) {
        next if $land->orb || $land->town;
        
        # Search for towns and orbs in this sector to see if it will block us spawning the orb.
        # The two searches are different sizes, so we have to find the largest one

        my $town_search_size = round $config->{orb_distance_from_town_per_level} * $level * 2 - 1;
        my @town_range       = RPG::Map->surrounds( $land->x, $land->y, $town_search_size, $town_search_size );
        my $orb_search_size  = $config->{orb_distance_from_other_orb} * 2 - 1;
        my @orb_range        = RPG::Map->surrounds( $land->x, $land->y, $orb_search_size, $orb_search_size );

        my @range;
        if ( $town_search_size > $orb_search_size ) {
            @range = @town_range;
        }
        else {
            @range = @orb_range;
        }

        for my $x ( $range[0]->{x} .. $range[1]->{x} ) {
            for my $y ( $range[0]->{y} .. $range[1]->{y} ) {
                next if $x > $x_y_range{max_x} || $y > $x_y_range{max_y};

                my $sector_to_check = $land_by_sector->[$x][$y];
                
                # If we haven't got enough surrounds, don't use this sector
                next OUTER unless $sector_to_check;
                
                # Orb must be minium range from town
                if ( $x >= $town_range[0]->{x} && $x <= $town_range[1]->{x} && $y >= $town_range[0]->{y} && $y <= $town_range[1]->{y} ) {
                    next OUTER if $sector_to_check->town;
                }

                # Check for orbs
                if ( $x >= $orb_range[0]->{x} && $x <= $orb_range[1]->{x} && $y >= $orb_range[0]->{y} && $y <= $orb_range[1]->{y} ) {
                    next OUTER if $used->[$x][$y] || $sector_to_check->orb;
                }
            }
        }

        # No towns in range, and no existing orb here... we can use this sector
        $package->_spawn_orb( $schema, $land, $level );

        $used->[ $land->x ][ $land->y ] = 1;

        $created = 1;

        last;
    }

    return $created;
}

my @names;

sub _spawn_orb {
    my $package = shift;
    my $schema  = shift;
    my $land    = shift;
    my $level   = shift;

    unless (@names) {
        @names = read_file( $ENV{RPG_HOME} . '/script/data/orb_names.txt' );
        chomp @names;
    }

    my $name;
    my $existing_orb;
    do {
        $name = ( shuffle @names )[0];
        $existing_orb = $schema->resultset('Creature_Orb')->find( { name => $name, land_id => {'!=', undef} } );
    } while ($existing_orb);

    $schema->resultset('Creature_Orb')->create(
        {
            land_id => $land->id,
            level   => $level,
            name    => $name
        }
    );

    # Create creature group at orb
    $package->_create_group( $schema, $land, $level * 3, $level * 3 );
}

1;
