package RPG::C::Dungeon;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature "switch";

use Data::Dumper;
use Carp;
use List::Util qw(shuffle);
use Statistics::Basic qw(average);

use RPG::Map;
use RPG::NewDay::Action::Dungeon;

sub view : Local {
    my ( $self, $c ) = @_;

    $c->stats->profile("Entered /dungeon/view");

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => 'dungeon_room', } );

    $c->log->debug( "Current location: " . $current_location->x . ", " . $current_location->y );

    # Get all sectors that the party has mapped
    my @mapped_sectors = $c->model('DBIC::Dungeon_Grid')->get_party_grid( $c->stash->{party}->id, $current_location->dungeon_room->dungeon_id );

    $c->stats->profile("Queried map sectors");

    my $mapped_sectors_by_coord;
    foreach my $sector (@mapped_sectors) {
        $mapped_sectors_by_coord->[ $sector->{x} ][ $sector->{y} ] = $sector;
    }

    # Find actual list of sectors party can move to
    my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );
    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                         => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                         => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_id' => $current_location->dungeon_room->dungeon_id,
        },
        {
            prefetch => [ 'dungeon_room', { 'doors' => 'position' }, { 'walls' => 'position' }, { 'party' => { 'characters' => 'class' } }, ],

        },
    );

    my $allowed_to_move_to = $current_location->allowed_to_move_to_sectors( \@sectors, $c->config->{dungeon_move_maximum} );

    $c->forward( 'store_allowed_move_hashes', [$allowed_to_move_to] );

    $c->stats->profile("Got sectors allowed to move to");

    # Get cgs in viewable area
    my $cgs;
    my @cg_recs = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                              => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                              => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
        },
        {
            prefetch => [ { 'creature_group' => { 'creatures' => 'type' } }, ],
            join     => 'dungeon_room',
        },
    );
    foreach my $cg_rec (@cg_recs) {
        my $cg = $cg_rec->creature_group;
        $cg->{group_size} = scalar $cg->creatures if $cg;
        $cgs->[ $cg_rec->x ][ $cg_rec->y ] = $cg;
    }

    my $parties;

    # Find viewable sectors, add newly discovered sectors to party's map, and get list of other parties nearby
    my @viewable_sectors;
    foreach my $sector (@sectors) {
        next unless $sector->dungeon_room_id == $current_location->dungeon_room_id;

        #$c->log->debug("Adding: " . $sector->x . ", " . $sector->y . " to viewable sectors");

        #$viewable_sectors->[ $sector->x ][ $sector->y ] = 1;
        push @viewable_sectors, $sector;

        # Save newly mapped sectors
        unless ( $mapped_sectors_by_coord->[ $sector->x ][ $sector->y ] ) {
            my $mapped = $c->model('DBIC::Mapped_Dungeon_Grid')->create(
                {
                    party_id        => $c->stash->{party}->id,
                    dungeon_grid_id => $sector->dungeon_grid_id,
                }
            );

            push @mapped_sectors, { $sector->get_as_hash };
        }

        if ( $sector->party && $sector->party->id != $c->stash->{party}->id ) {
            next if $sector->party->defunct;
            $parties->[ $sector->x ][ $sector->y ] = $sector->party;
        }
    }

    # Make sure all the viewable sectors have a path back to the starting square (i.e. there's no breaks in the viewable area,
    #  avoids the problem of twisting corridors having two lighted sections)
    # TODO: prevent light going round corners (?)
    my $viewable_sectors_by_coord;
    foreach my $viewable_sector (@viewable_sectors) {
        $viewable_sectors_by_coord->[ $viewable_sector->x ][ $viewable_sector->y ] = $viewable_sector;
    }

    my $viewable_sector_grid;

    for my $viewable_sector (@viewable_sectors) {
        if ( $viewable_sector->check_has_path( $current_location, $viewable_sectors_by_coord, 3 ) ) {
            $viewable_sector_grid->[ $viewable_sector->x ][ $viewable_sector->y ] = 1;
        }
    }

    #warn "viewable sectors: " . scalar @viewable_sectors;

    $c->stats->profile("Saved newly discovered sectors");

    return $c->forward( 'render_dungeon_grid', [ $viewable_sector_grid, \@mapped_sectors, $allowed_to_move_to, $current_location, $cgs, $parties ] );
}

sub render_dungeon_grid : Private {
    my ( $self, $c, $viewable_sectors, $mapped_sectors, $allowed_to_move_to, $current_location, $cgs, $parties ) = @_;

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

    my $grid;
    my ( $min_x, $min_y, $max_x, $max_y ) = ( $mapped_sectors->[0]->{x}, $mapped_sectors->[0]->{y}, 0, 0 );

    foreach my $sector (@$mapped_sectors) {

        #$c->log->debug( "Rendering: " . $sector->{x} . ", " . $sector->{y} );
        $grid->[ $sector->{x} ][ $sector->{y} ] = $sector;

        $max_x = $sector->{x} if $max_x < $sector->{x};
        $max_y = $sector->{y} if $max_y < $sector->{y};
        $min_x = $sector->{x} if $min_x > $sector->{x};
        $min_y = $sector->{y} if $min_y > $sector->{y};
    }

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/view.html',
                params   => {
                    grid                => $grid,
                    viewable_sectors    => $viewable_sectors,
                    max_x               => $max_x,
                    max_y               => $max_y,
                    min_x               => $min_x,
                    min_y               => $min_y,
                    positions           => \@positions,
                    current_location    => $current_location,
                    allowed_to_move_to  => $allowed_to_move_to,
                    cgs                 => $cgs,
                    parties             => $parties,
                    allowed_move_hashes => $c->flash->{allowed_move_hashes},
                    in_combat           => $c->stash->{party} ? $c->stash->{party}->in_combat_with : undef,
                    zoom_level => $c->session->{zoom_level} || 2,
                },
                return_output => 1,
            }
        ]
    );
}

sub move_to : Local {
    my ( $self, $c, $sector_id, $no_hash_check ) = @_;

    $sector_id ||= $c->req->param('sector_id');

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => 'dungeon_room', } );

    my $sector = $c->model('DBIC::Dungeon_Grid')->find( { 'dungeon_grid_id' => $sector_id, }, { prefetch => 'dungeon_room', } );

    croak "Can't find sector: $sector_id" unless $sector;

    $c->log->debug( "Attempting to move to " . $sector->x . ", " . $sector->y );

    # Check they're moving to a sector in the dungeon they're currently in
    if ( $current_location->dungeon_room->dungeon_id != $current_location->dungeon_room->dungeon_id ) {
        croak "Can't move to sector: $sector_id - in the wrong dungeon";
    }

    if (! $no_hash_check && $c->req->param('h') != $c->flash->{allowed_move_hashes}[$sector->x][$sector->y]) {
        $c->stash->{error} = "You must be in range of the sector";
    }
    elsif ( $c->stash->{party}->turns < 1 ) {
        $c->stash->{error} = "You do not have enough turns to move there";
    }
    else {
        $c->forward( 'check_for_creature_move', [$current_location] );

        my $creature_group = $c->forward( '/dungeon/combat/check_for_attack', [$sector] );

        # If creatures attacked, refresh party panel
        if ($creature_group) {
            push @{ $c->stash->{refresh_panels} }, 'party';
        }

        $c->stash->{party}->dungeon_grid_id($sector_id);
        $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
        $c->stash->{party}->update;
        $c->stash->{party}->discard_changes;
    }

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

sub check_for_creature_move : Private {
    my ( $self, $c, $current_location ) = @_;

    my @creatures_in_room =
        $c->model('DBIC::CreatureGroup')
        ->search( { 'dungeon_grid.dungeon_room_id' => $current_location->dungeon_room_id, }, { prefetch => 'dungeon_grid', }, );

    my @possible_sectors = shuffle $c->model('DBIC::Dungeon_Grid')->search(
        {
            'dungeon_room_id'                  => $current_location->dungeon_room_id,
            'creature_group.creature_group_id' => undef,
        },
        { join => 'creature_group', }
    );

    foreach my $cg (@creatures_in_room) {
        next if $cg->in_combat_with;

        next if Games::Dice::Advanced->roll('1d100') > $c->config->{creature_move_chance_on_party_move};

        my $sector_to_move_to = shift @possible_sectors;

        if ($sector_to_move_to) {
            $cg->dungeon_grid_id( $sector_to_move_to->id );
            $cg->update;
        }
    }
}

sub open_door : Local {
    my ( $self, $c ) = @_;

    my ($door) = $c->model('DBIC::Door')->search( 
        {
            door_id => $c->req->param('door_id'),
            'dungeon_grid_id' => $c->stash->{party}->dungeon_grid_id,
        },
    );

    if ( !$door || !$door->can_be_passed ) {
        croak "Cannot open door";
    }

    my ( $opposite_x, $opposite_y ) = $door->opposite_sector;

    $c->log->debug("Opening door, and moving to sector: $opposite_x, $opposite_y");

    my $sector_to_move_to = $c->model('DBIC::Dungeon_Grid')->find(
        {
            x                         => $opposite_x,
            y                         => $opposite_y,
            'dungeon_room.dungeon_id' => $door->dungeon_grid->dungeon_room->dungeon_id,
        },
        { join => 'dungeon_room', }
    );

    $c->forward( 'move_to', [ $sector_to_move_to->id, 1 ] );
}

sub sector_menu : Local {
    my ( $self, $c ) = @_;

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')
        ->find( 
        	{ 
        		dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, 
        	}, 
        	{ 
        		prefetch => [
        			{'doors' => 'position'},
        			'treasure_chest',
        		],        		
       		} 
       	);

    my $creature_group = $current_location->available_creature_group;

    my @doors = $current_location->available_doors;

    my $parties_in_sector = $c->forward( '/party/parties_in_sector', [ undef, $current_location->id ] );

    my $creature_group_display = $c->forward( '/combat/display_cg', [ $creature_group, 1 ] );

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/sector.html',
                params   => {
                    doors                  => \@doors,
                    current_location       => $current_location,
                    creature_group_display => $creature_group_display,
                    creature_group         => $creature_group,
                    messages               => $c->stash->{messages},
                    parties_in_sector      => $parties_in_sector,
                },
                return_output => 1,
            }
        ]
    );
}

sub unblock_door : Local {
    my ( $self, $c ) = @_;

    if ( $c->stash->{party}->turns <= 0 ) {
        $c->stash->{error} = "You don't have enough turns to attempt that";
        $c->detach( '/panel/refresh', ['messages'] );
    }

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, );

    my $door = $c->model('DBIC::Door')->find( { door_id => $c->req->param('door_id') } );

    croak "Door not in this sector" unless $current_location->id == $door->dungeon_grid_id;

    my %action_for_door = (
        charge => 'stuck',
        pick   => 'locked',
        break  => 'sealed',
    );

    my $success = 0;

    my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters;

    # Only attempt to unblock door if action matches door's type
    if ( $action_for_door{ $c->req->param('action') } eq $door->type ) {

        my %stats = (
            charge => [ 'strength',     'constitution' ],
            pick   => [ 'agility',      'intelligence' ],
            break  => [ 'intelligence', 'divinity' ],
        );

        my $stats = $stats{ $c->req->param('action') };
        my $stat_avg = average $character->get_column( $stats->[0] ), $character->get_column( $stats->[1] );

        my $roll_base              = 15;
        my $dungeon_level_addition = $current_location->dungeon_room->dungeon->level * 5;
        my $roll                   = Games::Dice::Advanced->roll( '1d' . $roll_base + $dungeon_level_addition );

        if ( $roll < $stat_avg ) {
            $success = 1;
            $door->state('open');
            $door->update;

            my $opposite_door = $door->opposite_door;
            $opposite_door->state('open');
            $opposite_door->update;

            $c->stash->{refresh_panels} = ['map'];
        }
    }

    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/unblock_door_message.html',
                params   => {
                    door      => $door,
                    success   => $success,
                    character => $character,
                    action    => $c->req->param('action'),
                },
                return_output => 1,
            }
        ]
    );

    $c->stash->{messages} = $message;

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub take_stairs : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, );

    croak "No stairs here" unless $current_location->stairs_up;

    # Reset zoom level
    $c->session->{zoom_level} = 2;

    $c->stash->{party}->dungeon_grid_id(undef);
    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status', 'zoom' ] );
}

sub search_room : Local {
    my ( $self, $c ) = @_;

    if ( $c->stash->{party}->turns <= 0 ) {
        $c->stash->{error} = "You don't have enough turns to attempt that";
        $c->detach( '/panel/refresh', ['messages'] );
    }

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')
        ->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => { 'dungeon_room' => 'dungeon' }, }, );

    my $found_something        = 0;
    my @available_secret_doors = $c->model('DBIC::Door')->get_secret_doors_in_room( $current_location->dungeon_room_id );

    # Remove secret doors in sectors the party doesn't know about
    my @secret_doors;
    my %mapped_sectors_by_id = map { $_->id => 1 } $c->model('DBIC::Dungeon_Grid')->search(
        {
            party_id             => $c->stash->{party}->id,
            'dungeon.dungeon_id' => $current_location->dungeon_room->dungeon_id,
        },
        { join => [ { 'dungeon_room' => 'dungeon' }, 'mapped_dungeon_grid' ], }
    );

    foreach my $secret_door (@available_secret_doors) {
        if ( $mapped_sectors_by_id{ $secret_door->dungeon_grid_id } ) {
            push @secret_doors, $secret_door;
        }
    }

    if (@secret_doors) {
        my $avg_int = $c->stash->{party}->average_stat('intelligence');

        my $roll = Games::Dice::Advanced->roll( '1d' . ( 15 + ( $current_location->dungeon_room->dungeon->level * 5 ) ) );

        if ( $roll <= $avg_int ) {
            my $door_found = ( shuffle @secret_doors )[0];

            $door_found->state('open');
            $door_found->update;

            my $opposite_door = $door_found->opposite_door;
            $opposite_door->state('open');
            $opposite_door->update;

            $found_something = 1;

            $c->stash->{messages} = "You find a secret door to the " . $door_found->display_position . "!";
        }
    }

    unless ($found_something) {
        $c->stash->{messages} = "You don't find anything of interest.";
    }

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

# Generates hashes of allowed moves, and saves them in the flash, so we can check only allowed sectors were passed to move_to
sub store_allowed_move_hashes : Private {
    my ( $self, $c, $allowed_to_move_to ) = @_;

    my $allowed_hashes;
    foreach my $x ( 0 .. scalar @$allowed_to_move_to ) {
        if ($allowed_to_move_to->[$x]) {
            foreach my $y ( 0 .. scalar @{ $allowed_to_move_to->[$x] } ) {
                if ( $allowed_to_move_to->[$x][$y] ) {
                    $allowed_hashes->[$x][$y] = int rand 100000000;
                }
            }
        }
    }

    $c->flash->{allowed_move_hashes} = $allowed_hashes;
}

sub open_chest : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, },
    	{
    		prefetch => {'treasure_chest' => 'items'},
    	},
    );

    croak "No chest here" unless $current_location->treasure_chest;
    
    if ($current_location->treasure_chest->trap) {
    	$c->detach('handle_chest_trap', [$current_location]);
    }

	my @items = $current_location->treasure_chest->items;
	
	my @characters = $c->stash->{party}->characters;
	
	my @items_found;
	
	foreach my $item (@items) {
        my $finder;
        foreach my $character ( shuffle @characters ) {
            unless ( $character->is_dead ) {
                $finder = $character;
                last;
            }
        }		
        
        $item->add_to_characters_inventory($finder);
        
        push @items_found, {
        	character => $finder,
        	item => $item,
        };
	}
	
    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/open_chest.html',
                params   => {
                    items_found => \@items_found,
                },
                return_output => 1,
            }
        ]
    );

    $c->stash->{messages} = $message;

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub handle_chest_trap : Private {
	my ( $self, $c, $current_location ) = @_;
	
	my $avg_div = $c->stash->{party}->average_stat('divinity');
	unless ($c->session->{detected_trap}[$current_location->x][$current_location->y] || 
		Games::Dice::Advanced->roll('1d30') <= $avg_div) {
		# Failed to detect trap
		$c->detach('trigger_trap', [$current_location]);
	}
	
	$c->stash->{dialog_to_display} = 'chest-trap';
	
	$c->session->{detected_trap}[$current_location->x][$current_location->y] = 1;
	
	$c->forward( '/panel/refresh', [ 'messages' ] );	
}

sub disarm_trap : Local {
	my ( $self, $c ) = @_;
	
    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, },
    	{
    		prefetch => {'treasure_chest' => 'items'},
    	},
    );

    croak "No chest here" unless $current_location->treasure_chest;
    
    unless ($current_location->treasure_chest->trap) {
    	# Could have been someone else disarming it?
    	$c->stash->{messages} = "The trap seems to have disappeared on it's own";	
    	$c->detach( '/panel/refresh', [ 'messages' ] );
    }
    
    my $avg_int = $c->stash->{party}->average_stat('intelligence');
	if (Games::Dice::Advanced->roll('1d30') <= $avg_int) {
		$current_location->treasure_chest->trap(undef);
		$current_location->treasure_chest->update;
		
    	$c->stash->{messages} = "Trap disarmed!";	
    	$c->detach( '/panel/refresh', [ 'messages' ] );
	}
	else {
		$c->forward('trigger_trap', [$current_location]);
	}	
}

sub trigger_trap : Private {
	my ( $self, $c, $current_location ) = @_;

	my $chest = $current_location->treasure_chest;
	
	my $dungeon = $current_location->dungeon_room->dungeon;
	
	my $target = (shuffle(grep { ! $_->is_dead } $c->stash->{party}->characters))[0];
	my $trap_variable;
	
	given($chest->trap) {
		when ("Curse") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $dungeon->level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Cursed',
				target => $target,
				duration => $trap_variable,
				modifier => -8 * $dungeon->level,
				combat => 0,
				modified_state => 'attack_factor',					
			});	
		}
		
		when ("Hypnotise") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $dungeon->level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Hypnotised',
				target => $target,
				duration => $trap_variable,
				modifier => -4,
				combat => 0,
				modified_state => 'attack_frequency',					
			});	
		}	
		
		when ("Detonate") {
			$trap_variable = Games::Dice::Advanced->roll('2d4') * $dungeon->level;
			$target->hit($trap_variable);
		}				
	}
	
    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/trigger_chest_trap.html',
                params   => {
                    target => $target,
                    trap => $chest->trap,
                    trap_variable => $trap_variable,
                    
                },
                return_output => 1,
            }
        ]
    );

    $c->stash->{messages} = $message;	
	
	$current_location->treasure_chest->trap(undef);
	$current_location->treasure_chest->update;
	
    $c->detach( '/panel/refresh', [ 'messages', 'party' ] );
		
}
 

1;
