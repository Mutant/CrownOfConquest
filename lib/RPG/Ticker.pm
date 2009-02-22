use strict;
use warnings;

package RPG::Ticker;

use Carp;

use RPG::Schema;
use RPG::Map;
use RPG::Maths;

use RPG::Ticker::LandGrid;
use RPG::Ticker::DungeonGrid;
use RPG::Ticker::Context;

use YAML;
use Data::Dumper;
use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;
use File::Slurp qw(read_file);
use Math::Round qw(round);
use Proc::PID::File;
use DBIx::Class::ResultClass::HashRefInflator;

sub run {
    my $self = shift;

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

        my $land_grid = RPG::Ticker::LandGrid->new( schema => $schema );
        #my $dungeon_grid = RPG::Ticker::DungeonGrid->new( schema => $schema );

        my $context = RPG::Ticker::Context->new(
            config       => $config,
            logger       => $logger,
            schema       => $schema,
            land_grid    => $land_grid,
            #dungeon_grid => $dungeon_grid,
        );

        # Clean up
        $self->clean_up($context);

        # Spawn orbs
        $self->spawn_orbs($context);

        # Spawn town orbs
        $self->spawn_town_orbs($context);

        # Spawn monsters
        $self->spawn_monsters($context);

        # Move monsters
        $self->move_monsters($context);

        # Spawn dungeon monsters
        $self->spawn_dungeon_monsters($context);

        # Spawn dungeon monsters
        #$self->move_dungeon_monsters($context);

        $schema->storage->dbh->commit unless $schema->storage->dbh->{AutoCommit};
    };
    if ($@) {
        $logger->error("Error running ticker script: $@");
    }

    $logger->info('Ticker script ended');
}

# Every town has at least one level 1 orb nearby
sub spawn_town_orbs {
    my $self = shift;
    my $c    = shift;

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

            my $created = $self->_create_orb_in_land( $c, 1, $start_point, $end_point );

            unless ($created) {
                $c->logger->warning( "Couldn't create orb near " . $town->{town_name} . " as no suitable land could be found" );
            }
        }
    }
}

sub spawn_orbs {
    my $self = shift;
    my $c    = shift;

    my $land_size = $c->schema->resultset('Land')->search->count;

    my $ideal_number_of_orbs = int $land_size / $c->config->{land_per_orb};

    my $orbs_to_create = $ideal_number_of_orbs - $c->schema->resultset('Creature_Orb')->count( land_id => { '!=', undef } );

    return if $orbs_to_create <= 0;
    $c->logger->info("Creating $orbs_to_create orbs");

    for my $orb_number ( 1 .. $orbs_to_create ) {
        my $level = RPG::Maths->weighted_random_number( 1 .. $c->config->{max_orb_level} );

        $c->logger->debug("Creating orb # $orb_number (level: $level)");

        my $created = $self->_create_orb_in_land( $c, $level, { x => 1, y => 1 }, { x => $c->land_grid->max_x, y => $c->land_grid->max_y } );

        unless ($created) {

            # Warn that we weren't able to create an orb
            $c->logger->warning("Unable to create orb # $orb_number, as no suitable land could be found");
        }

    }
}

sub spawn_monsters {
    my $self = shift;
    my $c    = shift;

    my $number_of_groups_to_spawn = $self->_calculate_number_of_groups_to_spawn( $c->config, $c->schema );

    $c->logger->info("Spawning $number_of_groups_to_spawn monsters");

    return if $number_of_groups_to_spawn <= 0;

    my $orb_rs = $c->schema->resultset('Creature_Orb')->search( {}, { prefetch => 'land', land_id => { '!=', undef } } );

    $orb_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my @creature_orbs = $orb_rs->all;

    my %orb_surrounds;

    my $level_rs = $c->schema->resultset('CreatureType')->find(
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

        #warn "Using creature orb at: $creature_orb->{land}{x}, $creature_orb->{land}{y}";

        my $land;

        my $search_range = 0;

        while ( !$land ) {
            my ( $start_point, $end_point ) = RPG::Map->surrounds_by_range( $creature_orb->{land}{x}, $creature_orb->{land}{y}, $search_range );

            for my $x ( $start_point->{x} .. $end_point->{x} ) {
                for my $y ( $start_point->{y} .. $end_point->{y} ) {

                    my $possible_sector = $c->land_grid->get_land_at_location( $x, $y );

                    next unless $possible_sector;

                    if ( !$possible_sector->{creature_group} && !$possible_sector->{town} ) {
                        $land = $possible_sector;

                        #warn "using sector: $x, $y";
                        last;
                    }
                }
            }

            $search_range++;

            last if $search_range > 20;
        }

        if ($land) {
            my $level = RPG::Maths->weighted_random_number( 1 .. $creature_orb->{level} * 3 );

            $self->_create_group_in_land( $c, $land, $level, $level );

            if ( $group_number % 100 == 0 ) {
                $c->logger->info("Spawned $group_number groups...");
            }
        }
        else {
            $c->logger->warning("Couldn't find a suitable sector to spawn in");
        }
    }
}

sub spawn_dungeon_monsters {
    my $self = shift;
    my $c    = shift;

    my $dungeon_rs = $c->schema->resultset('Dungeon')->search();

    $dungeon_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $level_rs = $c->schema->resultset('CreatureType')->find(
        {},
        {
            select => [              { max => 'level' }, { min => 'level' }, ],
            as     => [ 'max_level', 'min_level' ],
        }
    );

    while ( my $dungeon = $dungeon_rs->next ) {
        $c->logger->info( "Spawning groups for dungeon id: " . $dungeon->{dungeon_id} );

        my $creature_count =
            $c->schema->resultset('CreatureGroup')
            ->search( { 'dungeon_room.dungeon_id' => $dungeon->{dungeon_id}, }, { join => { 'dungeon_grid' => 'dungeon_room' }, } )->count;

        my $sector_count =
            $c->schema->resultset('Dungeon_Grid')->search( { 'dungeon_room.dungeon_id' => $dungeon->{dungeon_id}, }, { join => 'dungeon_room', } )
            ->count;

        $c->logger->debug("Current count: $creature_count, Number of sectors: $sector_count");

        my $number_of_groups_to_spawn = ( int $sector_count / $c->config->{dungeon_sectors_per_creature} ) - $creature_count;

        $c->logger->info( "Spawning $number_of_groups_to_spawn monsters in dungeon id: " . $dungeon->{dungeon_id} );

        next if $number_of_groups_to_spawn <= 0;

        # Spawn random groups
        my $spawned = {};

        for my $group_number ( 1 .. $number_of_groups_to_spawn ) {
            my $level_range_start = $dungeon->{level} * 5 - 7;
            $level_range_start = 1 if $level_range_start < 1;
            my $level_range_end = $dungeon->{level} * 5;

            my $level = RPG::Maths->weighted_random_number( $level_range_start .. $level_range_end );

            my $sector_to_spawn = $c->schema->resultset('Dungeon_Grid')->find(
                { 'dungeon_room.dungeon_id' => $dungeon->{dungeon_id}, },
                {
                    order_by => 'rand()',
                    rows     => 1,
                    join     => 'dungeon_room',
                    prefetch => 'creature_group',
                }
            );

            $self->_create_group_in_dungeon( $c->schema, $sector_to_spawn, $level, $level );

            if ( $group_number % 50 == 0 ) {
                $c->logger->info("Spawned $group_number groups...");
            }
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

sub _create_group_in_land {
    my ( $package, $c, $land, $min_level, $max_level ) = @_;

    my $land_record = $c->schema->resultset('Land')->find(
        {
            x => $land->{x},
            y => $land->{y},
        },
        { prefetch => 'creature_group', },
    );

    my $cg = $package->_create_group( $c->schema, $land_record, $min_level, $max_level );

    return unless $cg;

    $c->land_grid->set_land_object( 'creature_group', $land->{x}, $land->{y} );

    $cg->land_id( $land_record->id );
    $cg->update;

    $land_record->creature_threat( $land_record->creature_threat + 5 );
    $land_record->update;

    return $cg;
}

sub _create_group {
    my ( $package, $schema, $sector, $min_level, $max_level ) = @_;

    # TODO: check if level range is valid, i.e. check against max creature level from DB

    return if $sector->creature_group;

    @creature_types = $schema->resultset('CreatureType')->search()
        unless @creature_types;

    my $cg = $schema->resultset('CreatureGroup')->create( {} );

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

    return $cg;
}

sub _create_group_in_dungeon {
    my ( $package, $schema, $sector, $min_level, $max_level ) = @_;

    my $cg = $package->_create_group( $schema, $sector, $min_level, $max_level );

    return unless $cg;

    $cg->dungeon_grid_id( $sector->id );
    $cg->update;

    return $cg;
}

my %cant_move_reason;

sub move_monsters {
    my $self = shift;
    my $c    = shift;

    my $cg_rs =
        $c->schema->resultset('CreatureGroup')
        ->search( {}, { prefetch => [ { 'location' => 'orb', }, { 'creatures' => 'type' }, 'in_combat_with' ], }, );

    my $cg_count = $cg_rs->count;

    $c->logger->info("Moving monsters ($cg_count available)");

    my $moved           = 0;
    my $attempted_moves = 0;
    my $retries         = 0;

    my $cg;
    my @cgs_to_retry;
    while ( $cg = $cg_rs->next or $cg = shift @cgs_to_retry ) {
        $attempted_moves++;

        if ( $attempted_moves > $cg_count * 2 ) {

            # Stop trying to move cgs after a while...
            last;
        }

        my $cg_moved = 0;

        # Don't move creatures in combat, or guarding an orb
        next if $cg->in_combat_with || $cg->location->orb;

        next if Games::Dice::Advanced->roll('1d100') > $c->config->{creature_move_chance};

        # Find sector to move to.. try sectors immediately adjacent first, and then go one more sector if we can't find anything
        for my $hop_size ( 1 .. $c->config->{max_hops} ) {
            $cg_moved = $self->_move_cg( $c, $hop_size, $cg );

            if ($cg_moved) {
                $moved++;

                if ( $moved % 100 == 0 ) {
                    $c->logger->info("Moved $moved so far...");
                }
            }
        }

        unless ($cg_moved) {

            # Couldn't move this CG. Add it back into the array and try again later
            #  (After other cg's have moved and possibly cleared some space)
            $retries++;
            push @cgs_to_retry, $cg;
        }
    }

    $c->logger->info("Moved $moved groups ($retries retries)");
    $c->logger->debug( Dumper \%cant_move_reason );
}

sub move_dungeon_monsters {
    my $self = shift;
    my $c    = shift;

    my $cg_rs =
        $c->schema->resultset('CreatureGroup')
        ->search( {}, { prefetch => [ { 'dungeon_grid' => 'dungeon_room' }, 'in_combat_with' ], }, );

    my $cg_count = $cg_rs->count;

    $c->logger->info("Moving dungeon monsters ($cg_count available)");

    my $moved = 0;

    my $cg;
    my @cgs_to_retry;
    while ( $cg = $cg_rs->next ) {

        # Don't move creatures in combat
        next if $cg->in_combat_with;

        next if Games::Dice::Advanced->roll('1d100') > $c->config->{creature_move_chance};

        # Find sector to move to (if we can)
        my ( $start_point, $end_point ) = RPG::Map->surrounds_by_range( $cg->dungeon_grid->x, $cg->dungeon_grid->y, 1 );

        my @sectors = $c->dungeon_grid->get_sectors_within_range( $cg->dungeon_grid->dungeon_room->dungeon_id, $start_point, $end_point );

        foreach my $sector (@sectors) {

            # We're not checking if the move can usually be made (i.e. not moving thru walls..) but probably not an issue for creatures
            if ( !$sector->{creature_group} ) {
                $cg->dungeon_grid_id( $sector->{id} );
                $cg->update;
                $c->dungeon_grid->clear_land_object( 'creature_group', $cg->dungeon_grid->dungeon_room->dungeon_id,
                    $cg->dungeon_grid->x, $cg->dungeon_grid->y );
                $c->dungeon_grid->set_land_object( 'creature_group', $cg->dungeon_grid->dungeon_room->dungeon_id, $sector->{x}, $sector->{y} );
                
                $moved++;
                
                last;
            }
        }
    }

    $c->logger->info("Moved $moved groups");
}

# Clean up any dead monster groups. These sometimes get created due to bugs
# In an ideal world (or at least one with transactions) this wouldn't be needed.
# We don't delete them, since the news needs to display them
sub clean_up {
    my $self = shift;
    my $c    = shift;

    my $cg_rs = $c->schema->resultset('CreatureGroup')->search( { land_id => { '!=', undef }, }, {} );

    while ( my $cg = $cg_rs->next ) {
        if ( $cg->number_alive <= 0 ) {
            $cg->land_id(undef);
            $cg->update;
        }
    }
}

sub _move_cg {
    my $package = shift;
    my $c       = shift;
    my $size    = shift;
    my $cg      = shift;

    my $cg_moved = 0;

    #warn "size: $size";
    #warn "loc: " . $cg->location->x . ", " . $cg->location->y;

    my ( $start_point, $end_point ) = RPG::Map->surrounds_by_range( $cg->location->x, $cg->location->y, $size );

    my @sectors = $c->land_grid->get_sectors_within_range( $start_point, $end_point );

    foreach my $sector ( shuffle @sectors ) {

        #warn Dumper $sector;
        # Can't move to a town or sector that already has a creature group
        if ( !$sector->{town} && !$sector->{creature_group} && ( ( $sector->{ctr} / 10 ) + 1 ) > $cg->level ) {
            my ( $orig_x, $orig_y ) = ( $cg->location->x, $cg->location->y );

            my $sector_record = $c->schema->resultset('Land')->find(
                {
                    x => $sector->{x},
                    y => $sector->{y},
                }
            );

            $cg->land_id( $sector_record->id );
            $cg->update;

            $sector_record->creature_threat( $sector_record->creature_threat + 1 );
            $sector_record->update;

            $c->land_grid->set_land_object( 'creature_group', $sector->{x}, $sector->{y} );
            $c->land_grid->clear_land_object( 'creature_group', $orig_x, $orig_y );

            $cg_moved = 1;

            last;
        }
        else {
            $cant_move_reason{town}++, next if $sector->{town};
            $cant_move_reason{cg}++,   next if $sector->{creature_group};
            $cant_move_reason{ctr}++;
        }
    }

    return $cg_moved;
}

sub _create_orb_in_land {
    my $self        = shift;
    my $c           = shift;
    my $level       = shift;
    my $start_point = shift;
    my $end_point   = shift;

    my $created = 0;

    my @sectors = $c->land_grid->get_sectors_within_range( $start_point, $end_point );

    OUTER: foreach my $land ( shuffle @sectors ) {

        #warn Dumper $land;
        my ( $x, $y ) = ( $land->{x}, $land->{y} );

        next if $land->{orb} || $land->{town};

        # Search for towns and orbs in this sector to see if it will block us spawning the orb.
        # The two searches are different sizes, so we have to find the largest one

        my @town_range = RPG::Map->surrounds_by_range( $x, $y, $c->config->{orb_distance_from_town_per_level} );
        my @orb_range  = RPG::Map->surrounds_by_range( $x, $y, $c->config->{orb_distance_from_other_orb} );

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
                if (   $x_to_check >= $town_range[0]->{x}
                    && $x_to_check <= $town_range[1]->{x}
                    && $y_to_check >= $town_range[0]->{y}
                    && $y_to_check <= $town_range[1]->{y} )
                {
                    next OUTER if $sector_to_check->{town};
                }

                # Check for orbs
                if (   $x_to_check >= $orb_range[0]->{x}
                    && $x_to_check <= $orb_range[1]->{x}
                    && $y_to_check >= $orb_range[0]->{y}
                    && $y_to_check <= $orb_range[1]->{y} )
                {
                    next OUTER if $sector_to_check->{orb};
                }
            }
        }

        # No towns in range, and no existing orb here... we can use this sector
        $self->_spawn_orb( $c, $land, $level );

        $c->land_grid->set_land_object( 'orb', $x, $y, );

        $created = 1;
    }

    return $created;
}

my @names;

sub _spawn_orb {
    my $package = shift;
    my $c       = shift;
    my $land    = shift;
    my $level   = shift;

    unless (@names) {
        @names = read_file( $ENV{RPG_HOME} . '/script/data/orb_names.txt' );
        chomp @names;
    }
    
    $c->logger->debug("Spawning Orb at $land->{x}, $land->{y}");

    my $name;
    my $existing_orb;
    do {
        $name = ( shuffle @names )[0];
        $existing_orb = $c->schema->resultset('Creature_Orb')->find( { name => $name, land_id => { '!=', undef } } );
    } while ($existing_orb);

    my $land_record = $c->schema->resultset('Land')->find(
        {
            x => $land->{x},
            y => $land->{y},
        }
    );

    $c->schema->resultset('Creature_Orb')->create(
        {
            land_id => $land_record->id,
            level   => $level,
            name    => $name
        }
    );

    # Create creature group at orb
    $package->_create_group_in_land( $c, $land, $level * 3, $level * 3 );
}

1;
