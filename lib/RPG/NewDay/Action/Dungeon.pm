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

use feature 'switch';

sub run {
    my $self = shift;

    $self->check_for_dungeon_deletion();

    $self->reconfigure_doors();

    my $c = $self->context;

    my $dungeons_rs = $c->schema->resultset('Dungeon')->search(
    	{
    		type => 'dungeon',
    	}
    );
    
    # Fill empty dungeon chests
    $self->fill_empty_chests();

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
        
		my $number_of_rooms = Games::Dice::Advanced->roll( $dungeon->level + 1 . 'd20' ) + 20;

        $self->generate_dungeon_grid( $dungeon, $number_of_rooms );
        $self->generate_treasure_chests( $dungeon );
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

    my $c = $self->context;

    my @dungeons = $c->schema->resultset('Dungeon')->search( { type => 'dungeon' }, { prefetch => 'location', }, );

    foreach my $dungeon (@dungeons) {
        if ( Games::Dice::Advanced->roll('1d200') <= 1 ) {

            # Make sure no parties are in the dungeon
            my $party_rs =
                $c->schema->resultset('Party')
                ->search( { 'dungeon.dungeon_id' => $dungeon->id, }, { join => { 'dungeon_location' => { 'dungeon_room' => 'dungeon' } }, }, );

            if ( $party_rs->count > 0 ) {
                $c->logger->info(
                    'Not deleting dungeon at: ' . $dungeon->location->x . ", " . $dungeon->location->y . " as it has 1 or more parties inside" );
                next;
            }

            $c->logger->info( 'Deleting dungeon at: ' . $dungeon->location->x . ", " . $dungeon->location->y );

            # Delete the dungeon
            $dungeon->delete;
        }
    }
}

sub reconfigure_doors {
    my $self = shift;

    my $c = $self->context;

    my @doors = $c->schema->resultset('Door')->search( {} );

    my $processed_doors;

    foreach my $door (@doors) {
        unless ( $processed_doors->[ $door->id ] ) {
            my $opp_door = $door->opposite_door;

            my $door_type;
            if ( Games::Dice::Advanced->roll('1d100') <= 15 ) {
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

sub generate_treasure_chests {
	my $self = shift;
	my $dungeon = shift;
	
	my @rooms = $dungeon->rooms;    
	
	foreach my $room (@rooms) {
		my $chest_roll = Games::Dice::Advanced->roll('1d100');
		if ($chest_roll <= 20) {
			# Create a chest in this room
			my @sectors = $room->sectors;
			
			# Choose a sector
			my $sector_to_use;
			foreach my $sector (shuffle @sectors) {
				unless ($sector->has_door) {
					$sector_to_use = $sector;
					last;
				}
			}
			
			# Couldn't find a sector to use... skip this room
			next unless $sector_to_use;
			
			my $chest = $self->context->schema->resultset('Treasure_Chest')->create(
				{
					dungeon_grid_id => $sector_to_use->id,
				}
			);
			
			$self->fill_chest($chest);
		}
	}
}

my %item_types_by_prevalence;
sub fill_chest {
	my $self = shift;
	my $chest = shift;
	
	my $dungeon = $chest->dungeon_grid->dungeon_room->dungeon;
	
	unless (%item_types_by_prevalence) {
		my @item_types = $self->context->schema->resultset('Item_Type')->search(
	        {
	            'category.hidden'           => 0,
	            'category.findable'			=> 1,
	        },
	        {
	            prefetch => { 'item_variable_params' => 'item_variable_name' },
	            join     => 'category',
	        },
	    );
	
	    map { push @{ $item_types_by_prevalence{ $_->prevalence } }, $_ } @item_types;
	}
	
	my $number_of_items = RPG::Maths->weighted_random_number(1..3);
				
	for (1..$number_of_items) {
		my $max_prevalence = Games::Dice::Advanced->roll('1d100') + (15 * $dungeon->level);
		$max_prevalence = 100 if $max_prevalence > 100;		

        my $item_type;
        while ( !defined $item_type ) {
            last if $max_prevalence > 100;
        	
    	    my @items = map { $_ <= $max_prevalence ? @{$item_types_by_prevalence{$_}} : () } keys %item_types_by_prevalence;
			$item_type = $items[ Games::Dice::Advanced->roll( '1d' . scalar @items ) - 1 ];
			
			$max_prevalence++;
		}
                
	    # We couldn't find a suitable item. Try again
	    next unless $item_type;
	    
	    my $enchantments = 0;
	    if (Games::Dice::Advanced->roll('1d100') <= 15) {
	    	$enchantments = RPG::Maths->weighted_random_number(1..3);
	    }
	            
		my $item = $self->context->schema->resultset('Items')->create_enchanted(
			{
				item_type_id      => $item_type->id,
			    treasure_chest_id => $chest->id,
			},
			{
				number_of_enchantments => $enchantments,
				max_value => $dungeon->level * 300,
			}
	    );
	}
	
	# Add a trap
	if (Games::Dice::Advanced->roll('1d100') <= 20) {
		$chest->add_trap;
		$chest->update;
	}
	else {
		$chest->trap(undef);
		$chest->update;
	}
	
}

sub fill_empty_chests {
	my $self = shift;
	
	my @chests = $self->context->schema->resultset('Treasure_Chest')->all;
	
	foreach my $chest (@chests) {
		if ($chest->is_empty) {
			if (Games::Dice::Advanced->roll('1d100') <= 50) {
				$self->fill_chest($chest);
			} 	
		}	
	}	
}

__PACKAGE__->meta->make_immutable;


1;
