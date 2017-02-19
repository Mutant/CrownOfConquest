package RPG::NewDay::Action::Dungeon;

use Moose;

extends 'RPG::NewDay::Base';
with 'RPG::NewDay::Role::DungeonGenerator';

use RPG::Map;
use RPG::Maths;
use Games::Dice::Advanced;
use List::Util qw(shuffle);

use Carp qw(confess croak);
use Data::Dumper;

sub run {
    my $self = shift;

    my $c = $self->context;
    
    my @dungeons = $c->schema->resultset('Dungeon')->search( { type => 'dungeon' }, { prefetch => 'location', }, );

    $self->check_for_dungeon_deletion(@dungeons);

    $self->reconfigure_doors(@dungeons);

    my $dungeons_rs = $c->schema->resultset('Dungeon')->search(
    	{
    		type => 'dungeon',
    	}
    );

	# Generate teleporters
	while (my $dungeon = $dungeons_rs->next) {
		$self->generate_teleporters($dungeon);
	}

    my $land_rs = $c->schema->resultset('Land')->search(
        {},
        {
            prefetch => [ 'town', 'dungeon' ],

        }
    );

    my $ideal_dungeons = int $land_rs->count / $c->config->{land_per_dungeon};

    my $dungeons_to_create = $ideal_dungeons - $dungeons_rs->count;

    $c->logger->info("Creating $dungeons_to_create dungeons");

    return if $dungeons_to_create < 1;

    my @land = $land_rs->all;

    my $land_by_sector;
    foreach my $sector (@land) {
        $land_by_sector->[ $sector->x ][ $sector->y ] = $sector;
    }

    my $dungeons_created = [];

    for ( 1 .. $dungeons_to_create ) {
        my $sector_to_use;
        eval { $sector_to_use = $self->_find_sector_to_create( \@land, $land_by_sector, $dungeons_created ); };
        if ($@) {
            if ( $@ =~ /Couldn't find sector to return/ ) {
                $c->logger->warning("Couldn't find a sector to create more dungeons - not enough space");
                last;
            }
            else {
                die $@;
            }
        }

        $dungeons_created->[ $sector_to_use->x ][ $sector_to_use->y ] = 1;
        
        my $dungeon = $c->schema->resultset('Dungeon')->create(
            {
                land_id => $sector_to_use->id,
                level   => RPG::Maths->weighted_random_number( 1 .. $c->config->{dungeon_max_level} ),
                type => 'dungeon',
            }
        );
        
        my $floors = RPG::Maths->weighted_random_number( 1 .. 3 );
        my @number_of_rooms;
        for (1..$floors) {
			push @number_of_rooms, Games::Dice::Advanced->roll( $dungeon->level + 1 . 'd20' ) + 20;
        }

        $self->generate_dungeon_grid( $dungeon, \@number_of_rooms );
        $c->logger->debug("Generating chests");
        $self->generate_treasure_chests( $dungeon );
        $c->logger->debug("Populating sector paths");
        $self->populate_sector_paths( $dungeon ); 
    }
}

sub _find_sector_to_create {
    my $self             = shift;
    my $land             = shift;
    my $land_by_sector   = shift;
    my $dungeons_created = shift;

    my $c = $self->context;

    my $sector_to_use;
    OUTER: foreach my $sector ( shuffle @$land ) {
        my ( $top, $bottom ) = RPG::Map->surrounds_by_range( $sector->x, $sector->y, $c->config->{min_distance_from_dungeon_or_town} );

        #warn Dumper $top;
        #warn Dumper $bottom;

        for my $x ( $top->{x} .. $bottom->{x} ) {
            for my $y ( $top->{y} .. $bottom->{y} ) {
                if ( $dungeons_created->[$x][$y]
                    || ( $land_by_sector->[$x][$y] && ( $land_by_sector->[$x][$y]->town || $land_by_sector->[$x][$y]->dungeon ) ) )
                {
                    next OUTER;
                }
            }
        }

        # If we get here, the sector must be ok
        $sector_to_use = $sector;
        last;
    }

    croak "Couldn't find sector to return" unless $sector_to_use;

    return $sector_to_use;
}



sub check_for_dungeon_deletion {
    my $self = shift;
    my @dungeons = @_;

    my $c = $self->context;

    foreach my $dungeon (@dungeons) {
        if ( Games::Dice::Advanced->roll('1d100') <= 1 ) {

            # Any parties in the dungeon get busted back to the surface
            my @parties = $c->schema->resultset('Party')->search( 
                { 
                    'dungeon.dungeon_id' => $dungeon->id, 
                }, 
                { 
                    join => { 'dungeon_grid' => { 'dungeon_room' => 'dungeon' } }, 
                }, 
            );
            
            foreach my $party (@parties) {
                $party->dungeon_grid_id(undef);
                $party->update;
                $party->add_to_messages(
                    {
                        day_id => $c->current_day->id,
                        alert_party => 1,
                        message => "There's a puff of smoke, and we suddenly realise we're no longer in the dungeon, but back on the surface!",
                    }
                );   
            }
            
            $c->logger->info( 'Deleting dungeon at: ' . $dungeon->location->x . ", " . $dungeon->location->y );

            # Delete the dungeon
            $dungeon->delete;
        }
    }
}

sub reconfigure_doors {
    my $self = shift;
    my @dungeons = @_;

    my $c = $self->context;    

    foreach my $dungeon (@dungeons) {
        my $parties_in_dungeon = $c->schema->resultset('Party')->search( 
            { 
                'dungeon.dungeon_id' => $dungeon->id, 
            }, 
            { 
                join => { 'dungeon_grid' => { 'dungeon_room' => 'dungeon' } }, 
            }, 
        )->count;
        
        # Don't reconfigure doors if there are parties in the dungeon
        next if $parties_in_dungeon > 0;        

        my @doors = $c->schema->resultset('Door')->search(
            { 
                'dungeon.dungeon_id' => $dungeon->id, 
            }, 
            { 
                join => { 'dungeon_grid' => { 'dungeon_room' => 'dungeon' } }, 
            }, 
        );
    
        my $processed_doors;
    
        foreach my $door (@doors) {
            unless ( $processed_doors->[ $door->id ] ) {
            	next unless $door->dungeon_grid->dungeon_room;
            	        	
                my $opp_door = $door->opposite_door;
    
                my $door_type;
                if ( Games::Dice::Advanced->roll('1d100') <= 10 ) {
                    $door_type = ( shuffle($self->alternative_door_types) )[0];
                }
                else {
                    $door_type = 'standard';
                }
                $door->type($door_type);
                $door->update;
    
                if ($opp_door) {
                    $opp_door->type($door_type);
                    $opp_door->update;
                }
    
                $processed_doors->[ $door->id ] = 1;
                $processed_doors->[ $opp_door->id ] = 1 if $opp_door;
            }
    
        }
    }
}

sub generate_teleporters {
	my $self = shift;
	my $dungeon = shift;	

	my $room_count = $dungeon->rooms->count;
	
	my @teleporters = $self->context->schema->resultset('Dungeon_Teleporter')->search(
		{
			'dungeon_room.dungeon_id' => $dungeon->id,
		},
		{
			join => {'dungeon_grid' => 'dungeon_room'},
		}
	);
	
	my $delete_teleporter = Games::Dice::Advanced->roll('1d100') <= 10 ? 1 : 0; 
	
	if ($delete_teleporter && @teleporters) {
		shuffle @teleporters;
		my $teleporter = shift @teleporters;
		$teleporter->delete;
	}
	
	my $optimal_teleporters = int $room_count / 20 + 1;
	my $teleporters_to_create = $optimal_teleporters - scalar @teleporters;
	
	for (1 .. $teleporters_to_create) {			
		my $sector = $self->_get_sector_for_teleporter($dungeon);
		my $target_id;
		
		my $random_destination = Games::Dice::Advanced->roll('1d100') <= 20 ? 1 : 0;
		if (! $random_destination) {		
			my $target = $self->_get_sector_for_teleporter($dungeon, $sector->dungeon_room_id);
			$target_id = $target->id;
		}
		
		my $invisible = Games::Dice::Advanced->roll('1d100') < 30 ? 1 : 0;
		
		$self->context->schema->resultset('Dungeon_Teleporter')->create(
			{
				dungeon_grid_id => $sector->id,
				destination_id => $target_id,
				invisible => $invisible,
			}
		);
		
		# Create two-way teleporter?
		# Can't be two-way if destination is random
		next if $random_destination;
		
		my $two_way = Games::Dice::Advanced->roll('1d100') <= 25 ? 1 : 0;
		if ($two_way) {
			$self->context->schema->resultset('Dungeon_Teleporter')->create(
				{
					dungeon_grid_id => $target_id,
					destination_id => $sector->id,
					invisible => $invisible,
				}
			);				
		}
	}
}

sub _get_sector_for_teleporter {
	my $self = shift;
	my $dungeon = shift;
	my $not_in_room = shift;
	
	my $sector;
	
	my $count = 0;
	while (! $sector) {
		$count++;
		die "Can't find sector to create teleporter in (dungeon id: " . $dungeon->id . ')' if $count > 500;				
		
		my $test_sector = $self->context->schema->resultset('Dungeon_Grid')->find_random_sector($dungeon->id);
		
		next if ! $test_sector || $test_sector->treasure_chest || $test_sector->teleporter || $test_sector->stairs_up || $test_sector->stairs_down ||$test_sector->sides_with_doors;
		
		next if defined $not_in_room && $test_sector->dungeon_room_id == $not_in_room; 
		
		$sector = $test_sector;
	}
	
	return $sector;	
}

__PACKAGE__->meta->make_immutable;


1;
