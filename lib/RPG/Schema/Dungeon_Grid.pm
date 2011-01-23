package RPG::Schema::Dungeon_Grid;

use strict;
use warnings;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;

use Clone qw(clone);
use List::MoreUtils qw/any/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Grid');

__PACKAGE__->resultset_class('RPG::ResultSet::Dungeon_Grid');

__PACKAGE__->add_columns(qw/dungeon_grid_id x y dungeon_room_id stairs_up stairs_down/);

__PACKAGE__->set_primary_key('dungeon_grid_id');

__PACKAGE__->has_many( 'doors', 'RPG::Schema::Door', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->has_many( 'walls', 'RPG::Schema::Dungeon_Wall', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->has_many( 'paths', 'RPG::Schema::Dungeon_Sector_Path', { 'foreign.sector_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->belongs_to( 'dungeon_room', 'RPG::Schema::Dungeon_Room', { 'foreign.dungeon_room_id' => 'self.dungeon_room_id' } );

__PACKAGE__->has_many( 'mapped_dungeon_grid', 'RPG::Schema::Mapped_Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->might_have( 'creature_group', 'RPG::Schema::CreatureGroup', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->might_have( 'party', 'RPG::Schema::Party', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->might_have( 'treasure_chest', 'RPG::Schema::Treasure_Chest', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->might_have( 'teleporter', 'RPG::Schema::Dungeon_Teleporter', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

sub sides_with_walls {
    my $self = shift;

    return @{ $self->{sides_with_walls} } if defined $self->{sides_with_walls};

    my @walls = $self->walls;

    my @sides_with_walls;

    foreach my $wall (@walls) {
        push @sides_with_walls, $wall->position->position;
    }

    $self->{sides_with_walls} = \@sides_with_walls;

    return @sides_with_walls;
}

sub has_wall {
    my $self      = shift;
    my $wall_side = shift;

    return (any { $wall_side eq $_ } $self->sides_with_walls) ? 1 : 0;
}

sub sides_with_doors {
    my $self = shift;
    my $passable_only = shift // 0;

    return @{ $self->{sides_with_doors} } if defined $self->{sides_with_doors} && ! $passable_only;
    return @{ $self->{sides_with_passable_doors} } if defined $self->{sides_with_passable_doors} && $passable_only;

    my @doors = $self->doors;

    my @sides_with_doors;
    my @sides_with_passable_doors;

    foreach my $door (@doors) {
        if ($door->can_be_passed) {
            push @sides_with_passable_doors, $door->position->position;
        }
        push @sides_with_doors, $door->position->position;
    }

    $self->{sides_with_doors} = \@sides_with_doors;
    $self->{sides_with_passable_doors} = \@sides_with_passable_doors;

    return $passable_only ? @sides_with_passable_doors : @sides_with_doors;
}

sub has_door {
    my $self      = shift;
    my $door_side = shift;
    
    if ($door_side) {
    	return grep { $door_side eq $_ } $self->sides_with_doors;
    }
    else {
    	return $self->sides_with_doors ? 1 : 0;
    }
}

sub has_passable_door {
    my $self      = shift;
    my $door_side = shift;
    
    return grep { $door_side eq $_ } $self->sides_with_doors(1);
}

# Returns the door at a particular position, or undef if none exists
sub get_door_at {
	my $self = shift;
	my $door_side = shift;
	
	return undef unless $self->has_door($door_side);
	
	my @doors = $self->doors;
	
    foreach my $door (@doors) {
        if ($door->position->position eq $door_side) {
        	return $door;	
        }
    }	
}

# Returns the wall at a particular position, or undef if none exists
sub get_wall_at {
	my $self = shift;
	my $wall_side = shift;
	
	return undef unless $self->has_wall($wall_side);
	
	my @walls = $self->walls;
	
    foreach my $wall (@walls) {
        if ($wall->position->position eq $wall_side) {
        	return $wall;	
        }
    }	
}

sub sectors_allowed_to_move_to {
    my $self      = shift;
    my $max_moves = shift;
    my $consider_doors = shift // 1;
    
    my %extra_params;
    $extra_params{prefetch} = {'doors_in_path' => 'door'} if $consider_doors;
    
    my @paths = $self->search_related(
    	'paths',
    	{
    		distance => {'<=', $max_moves},	
    	},
    	\%extra_params,
    );
    
    my %allowed;
    foreach my $path (@paths) {
    	# Skip path if a door in the path is not passable
    	if ($consider_doors && grep { ! $_->door->can_be_passed } $path->doors_in_path) {
    		next;    		
    	}
    	
    	$allowed{$path->has_path_to} = 1;
    }

    return \%allowed;
}

sub has_path_to {
    my $self          = shift;
    my $sector_id     = shift;
    my $max_moves     = shift || 3;
    
    my $path = $self->find_related(
    	'paths',
    	{
    		distance => {'<=', $max_moves},
    		has_path_to => $sector_id,
    	},
    );
    
    return $path ? 1 : 0;
}

sub available_creature_group {
    my $self = shift;

    my $creature_group = $self->find_related(
        'creature_group',
        {
            'in_combat_with.party_id' => undef,
        },
        {
            prefetch => { 'creatures' => [ 'type', 'creature_effects' ] },
            join     => 'in_combat_with',
            order_by => 'type.creature_type, group_order',
        }
    );

    return $creature_group;
}

sub get_as_hash {
    my $self = shift;
    
    my %result = (
        dungeon_grid_id => $self->id,
        x => $self->x,
        y => $self->y,
        stairs_up => $self->stairs_up,
        walls => [ $self->sides_with_walls ],
        doors => [ $self->sides_with_doors ],
        raw_doors => [ $self->doors ],
    );
    
    return %result;
}

sub available_doors {
    my $self = shift;
    
    return $self->search_related('doors',
        {
            -or => {
                type => {'!=', 'secret'},
                state => 'open',
            }
        }
    );
}

1;
