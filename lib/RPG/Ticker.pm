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

sub run {
    my $package = shift;

    my $home = $ENV{RPG_HOME};

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

sub spawn_orbs {
    my ( $package, $config, $schema, $logger ) = @_;

    my $land_rs = $schema->resultset('Land')->search(
        {},
        {
            order_by => 'rand()',
            prefetch => [ 'terrain', 'orb' ],
        }
    );

    my $land_size = $land_rs->count;

    my $ideal_number_of_orbs = int $land_size / $config->{land_per_orb};

    my $orbs_to_create = $ideal_number_of_orbs - $schema->resultset('Creature_Orb')->count();

    $logger->info("Creating $orbs_to_create orbs");

    my %x_y_range = $schema->resultset('Land')->get_x_y_range();

    my $used = {};

    for my $orb_number ( 1 .. $orbs_to_create ) {
        $logger->debug("Creating orb # $orb_number");

        my %coords;

        my $created = 0;
        while ( my $land = $land_rs->next ) {
            next if $land->orb || $land->terrain->terrain_name eq 'town';

            my $size = $config->{min_orb_distance_from_town} * 2 - 1;
            my @range = RPG::Map->surrounds( $land->x, $land->y, $size, $size );

            my @sectors = $schema->resultset('Land')->search(
                {
                    'x' => { '>=', $range[0]->{x}, '<=', $range[1]->{x} },
                    'y' => { '>=', $range[0]->{y}, '<=', $range[1]->{y} },
                },
                { prefetch => [ 'terrain', 'orb' ], }
            );

            my $towns = grep { $_->terrain->terrain_name eq 'town' } @sectors;

            next if $towns > 0;

            # No towns in range, and no existing orb here... we can use this sector

            $schema->resultset('Creature_Orb')->create( { land_id => $land->id, } );

            # Create creature group at orb
            $package->_create_group( $schema, $land, $config->{min_orb_level_cg}, $config->{max_orb_level_cg} );

            $created = 1;

            last;
        }

        unless ($created) {

            # Warn that we weren't able to create an orb
            $logger->warn("Unable to create orb # $orb_number, as no suitable land could be found");
        }
        else {

            # Create
        }
    }
}

sub spawn_monsters {
    my ( $package, $config, $schema, $logger ) = @_;

    my $number_of_groups_to_spawn = $package->_calculate_number_of_groups_to_spawn( $config, $schema );

    $logger->info("Spawning $number_of_groups_to_spawn monsters");

    return if $number_of_groups_to_spawn <= 0;

    my @creature_orbs = $schema->resultset('Creature_Orb')->search( {}, { prefetch => 'land', } );

    my %orb_surrounds;

    my $level_rs = $schema->resultset('CreatureType')->find(
        {},
        {
            select => [              { max => 'level' }, { min => 'level' }, ],
            as     => [ 'max_level', 'min_level' ],
        }
    );

    # Spawn random groups
    for ( 1 .. $number_of_groups_to_spawn ) {

        # Pick an orb to spawn near

        @creature_orbs = shuffle @creature_orbs;
        my $creature_orb = $creature_orbs[0];

        my $land;

        while ( !$land ) {

            # See if any of the sectors loaded around this orb are free
            my $count = 0;
            foreach my $possible_sector ( @{ $orb_surrounds{ $creature_orb->id }{sectors} } ) {
                if ( $possible_sector && !$possible_sector->creature_group ) {
                    $land = $possible_sector;

                    # Delete the sector out of the orb_surrounds array, so nothing will try to use it again.
                    #  Since we haven't re-read it from the DB, we won't find the creature group we've just added
                    #  Removing it prevents this.
                    undef $orb_surrounds{ $creature_orb->id }{sectors}->[$count];

                    last;
                }

                $count++;
            }

            # Load in more sectors to check if we couldn't find a suitable one
            unless ($land) {

                # Load in some sectors to check
                $orb_surrounds{ $creature_orb->id }{size}++;
                my $size_to_get = $orb_surrounds{ $creature_orb->id }{size};

                my @range = RPG::Map->surrounds( $creature_orb->land->x, $creature_orb->land->y, $size_to_get, $size_to_get );

                # Somewhat ineffecient, as we'll look thru a lot of sectors multiple times...
                my @sectors = $schema->resultset('Land')->search(
                    {
                        'x' => { '>=', $range[0]->{x}, '<=', $range[1]->{x} },
                        'y' => { '>=', $range[0]->{y}, '<=', $range[1]->{y} },
                    },
                    { prefetch => ['creature_group'], }
                );

                $orb_surrounds{ $creature_orb->id }{sectors} = \@sectors;
            }

        }

        my $level = RPG::Maths->weighted_random_number( $level_rs->get_column('min_level') .. $level_rs->get_column('max_level') );

        $package->_create_group( $schema, $land, $level, $level );
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

sub move_monsters {
    my ( $package, $config, $schema, $logger ) = @_;

    my $cg_rs =
        $schema->resultset('CreatureGroup')
        ->search( { 'location.land_id' => { '!=', undef }, }, { prefetch => [ { 'location' => 'orb' }, 'in_combat_with' ], }, );

    my %x_y_range = $schema->resultset('Land')->get_x_y_range();

    my $moved = 0;
    my $size = 3;
    while ( my $cg = $cg_rs->next ) {
        next if $cg->in_combat_with;

        next unless Games::Dice::Advanced->roll('1d100') > $config->{creature_move_chance};

        # Find sector to move to.. try sectors immediately adjacent first, and then go one more sector if we can't find anything
        OUTER: for my $size (3, 5) {
            my @range = RPG::Map->surrounds( $cg->location->x, $cg->location->y, $size, $size );
            my @sectors = $schema->resultset('Land')->search(
                {
                    'x' => { '>=', $range[0]->{x}, '<=', $range[1]->{x} },
                    'y' => { '>=', $range[0]->{y}, '<=', $range[1]->{y} },
                },
                { prefetch => [ 'creature_group', 'town' ], }
            );
    
            foreach my $sector (@sectors) {    
                # Can't move to a town or sector that already has a creature group
                if ( ! $sector->town && ! $sector->creature_group && ($sector->creature_threat / 10) + 1 > $cg->level ) {
                    $cg->land_id( $sector->id );
                    $cg->update;
    
                    $moved++;
    
                    #warn "Moving group " . $cg->id . " to " . $sector->[0] . "," . $sector->[1] . "\n";
                    last OUTER;
                }
            }
        }
    }

    $logger->info("Moved $moved groups");
}

# Clean up any dead monster groups. These sometimes get created due to bugs
# In an ideal world (or at least one with transactions) this wouldn't be needed.
# We don't delete them, since the news needs to display them
sub clean_up {
    my ( $package, $config, $schema, $logger ) = @_;

    my $cg_rs = $schema->resultset('CreatureGroup')->search();

    while ( my $cg = $cg_rs->next ) {
        if ( $cg->number_alive <= 0 ) {
            $cg->land_id(undef);
            $cg->update;
        }
    }
}

1;
