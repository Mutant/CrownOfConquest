package RPG::NewDay::Action::Creatures;
use Moose;

extends 'RPG::NewDay::Base';

use List::Util qw(shuffle);
use Data::Dumper;
use Try::Tiny;

with qw /
	RPG::NewDay::Role::GarrisonCombat
/;

use feature 'switch';

sub cron_string {
    my $self = shift;
     
    return $self->context->config->{creatures_cron_string};   
}

sub run {
    my $self = shift;

    # Spawn monsters
    $self->spawn_monsters();

    # Move monsters
    $self->move_monsters();

    # Spawn dungeon monsters
    $self->spawn_dungeon_monsters();    
}

sub spawn_monsters {
    my $self = shift;
    my $c    = $self->context;

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
            my $land_record = $c->schema->resultset('Land')->find(
                {
                    x => $land->{x},
                    y => $land->{y},
                },
                { prefetch => 'creature_group', },
            );

			my $min_level = ($creature_orb->{level} - 1) * 2 + 1;
			my $max_level = $creature_orb->{level} * 3;
			
            $c->schema->resultset('CreatureGroup')->create_in_wilderness( $land_record, $min_level, $max_level );

            $c->land_grid->set_land_object( 'creature_group', $land->{x}, $land->{y} );

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
    my $c    = $self->context;
    
    my $dungeon_rs = $c->schema->resultset('Dungeon')->search(
    	{
    		type => 'dungeon',
    	}
    );
    while ( my $dungeon = $dungeon_rs->next ) {
		$self->_spawn_in_dungeon($c, $dungeon);
    }
}

sub _spawn_in_dungeon {
	my $self = shift;
	my $c = shift;
	my $dungeon = shift;
	
    $c->logger->info( "Spawning groups for dungeon id: " . $dungeon->dungeon_id );

    my $creature_count =
        $c->schema->resultset('CreatureGroup')
        ->search( { 'dungeon_room.dungeon_id' => $dungeon->dungeon_id, }, { join => { 'dungeon_grid' => 'dungeon_room' }, } )->count;

    my $sector_count =
        $c->schema->resultset('Dungeon_Grid')->search( { 'dungeon_room.dungeon_id' => $dungeon->dungeon_id, }, { join => 'dungeon_room', } )
        ->count;

    $c->logger->debug("Current count: $creature_count, Number of sectors: $sector_count");

    my $number_of_groups_to_spawn = ( int $sector_count / $c->config->{dungeon_sectors_per_creature} ) - $creature_count;

    $c->logger->info( "Spawning $number_of_groups_to_spawn monsters in dungeon id: " . $dungeon->dungeon_id );

    return if $number_of_groups_to_spawn <= 0;

    # Spawn random groups
    my $spawned = {};

    for my $group_number ( 1 .. $number_of_groups_to_spawn ) {
        my $level_range_start = $dungeon->level * 5 - 7;
        $level_range_start = 1 if $level_range_start < 1;
        my $level_range_end = $dungeon->level * 5;

        my $sector_to_spawn = $c->schema->resultset('Dungeon_Grid')->find_random_sector( $dungeon->dungeon_id );

		try {
           	$c->schema->resultset('CreatureGroup')->create_in_dungeon( $sector_to_spawn, $level_range_start, $level_range_end );
		}
		catch {
			if (ref $_ && $_->isa('RPG::Exception')) {
				if ($_->type eq 'creature_type_error') {
					# Couldn't find a creature type.. just skip this group
					next;	
				}
			}
				
			die $_;	
		};

        if ( $group_number % 50 == 0 ) {
            $c->logger->info("Spawned $group_number groups...");
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

my %cant_move_reason;

sub move_monsters {
    my $self = shift;
    my $c    = $self->context;

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
        next unless $cg->land_id;

        $attempted_moves++;

        if ( $attempted_moves > $cg_count * 2 ) {

            # Stop trying to move cgs after a while...
            last;
        }

        my $new_sector;

        # Don't move creatures in combat, or guarding an orb
        next if $cg->in_combat_with || $cg->location->orb;

        next if Games::Dice::Advanced->roll('1d100') > $c->config->{creature_move_chance};

        # Find sector to move to.. try sectors immediately adjacent first, and then go one more sector if we can't find anything
        for my $hop_size ( 1 .. $c->config->{max_hops} ) {
            $new_sector = $self->_move_cg( $hop_size, $cg );

            if ($new_sector) {
                $moved++;
                
                # If there's a garrison, see if it wants to start a fight...
                if (my $garrison = $new_sector->garrison) {
                	$self->_check_for_fight($cg, $garrison);
                }

                if ( $moved % 100 == 0 ) {
                    $c->logger->info("Moved $moved so far...");
                }
                last;
            }
        }

        unless ($new_sector) {

            # Couldn't move this CG. Add it back into the array and try again later
            #  (After other cg's have moved and possibly cleared some space)
            $retries++;
            push @cgs_to_retry, $cg;
        }
    }

    $c->logger->info("Moved $moved groups ($retries retries)");
    $c->logger->debug( Dumper \%cant_move_reason );
}

sub _move_cg {
    my $self = shift;
    my $c       = $self->context;
    my $size    = shift;
    my $cg      = shift;

    my $new_sector;

    #warn "size: $size";
    #warn "loc: " . $cg->location->x . ", " . $cg->location->y;

    my ( $start_point, $end_point ) = RPG::Map->surrounds_by_range( $cg->location->x, $cg->location->y, $size );

    my @sectors = $c->land_grid->get_sectors_within_range( $start_point, $end_point );

    foreach my $sector ( shuffle @sectors ) {

        #warn Dumper $sector;
        # Can't move to a town or sector that already has a creature group
        if ( !$sector->{town} && !$sector->{creature_group}) {
        	
        	my $ctr_roll = ($cg->level * 20) - Games::Dice::Advanced->roll('1d20') - 100;
        	$ctr_roll = 90 if $ctr_roll > 90;
        	if ($sector->{ctr} < $ctr_roll) {
				$cant_move_reason{ctr}++;
				next;
        	}
        	
            my ( $orig_x, $orig_y ) = ( $cg->location->x, $cg->location->y );

            my $sector_record = $c->schema->resultset('Land')->find(
                {
                    x => $sector->{x},
                    y => $sector->{y},
                },
                {
                	prefetch => 'garrison',
                }
            );
            
            $cg->land_id( $sector_record->id );
            $cg->update;

			# Chance of CG increasing CTR is CG level * 2
			my $chance = $cg->level * 2;

			if (Games::Dice::Advanced->roll('1d100') <= $chance) {
            	$sector_record->creature_threat( $sector_record->creature_threat + 1 );
            	$sector_record->update;
			}

            $c->land_grid->set_land_object( 'creature_group', $sector->{x}, $sector->{y} );
            $c->land_grid->clear_land_object( 'creature_group', $orig_x, $orig_y );

            $new_sector = $sector_record;

            last;
        }
        else {
            $cant_move_reason{town}++, next if $sector->{town};
            $cant_move_reason{cg}++,   next if $sector->{creature_group};
        }
    }

    return $new_sector;
}

sub _check_for_fight {
	my $self = shift;
	my $cg = shift;
	my $garrison = shift;
		
	if ($self->check_for_garrison_fight($cg, $garrison, $garrison->creature_attack_mode)) {
		$self->execute_garrison_battle($garrison, $cg, 0);
	}
}

__PACKAGE__->meta->make_immutable;

1;
