use strict;
use warnings;

package RPG::Schema::Door;

use RPG::Position;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Door');

__PACKAGE__->resultset_class('RPG::ResultSet::Door');

__PACKAGE__->add_columns(qw/door_id position_id dungeon_grid_id type state/);

__PACKAGE__->set_primary_key('door_id');

__PACKAGE__->belongs_to( 'position', 'RPG::Schema::Dungeon_Position', { 'foreign.position_id' => 'self.position_id' } );

__PACKAGE__->belongs_to( 'dungeon_grid', 'RPG::Schema::Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

my %position_map = (
	bottom => 'south',
	top => 'north',
	left => 'west',
	right => 'east',
);

sub opposite_position {
    my $self = shift;

    return RPG::Position->opposite( $self->position->position );
}

sub opposite_sector {
    my $self = shift;

    return RPG::Position->opposite_sector( $self->position->position, $self->dungeon_grid->x, $self->dungeon_grid->y );
}

sub can_be_passed {
    my $self = shift;

    return $self->type eq 'standard' || $self->state eq 'open';
}

sub opposite_door {
    my $self = shift;
    
    confess "No room for sector " . $self->dungeon_grid->id unless $self->dungeon_grid->dungeon_room;
    
    my ( $opp_x, $opp_y ) = $self->opposite_sector;
    my $opp_door = $self->result_source->schema->resultset('Door')->find(
        {
            'dungeon_grid.x'          => $opp_x,
            'dungeon_grid.y'          => $opp_y,
            'dungeon_room.floor'      => $self->dungeon_grid->dungeon_room->floor,
            'dungeon_room.dungeon_id' => $self->dungeon_grid->dungeon_room->dungeon_id,
            'position.position'       => $self->opposite_position,
        },
        { join => [ { 'dungeon_grid' => 'dungeon_room' }, 'position' ] }
    );
    
    return $opp_door;
}

sub display_position {
    my $self = shift;
    
    return $position_map{$self->position->position};   
}

1;
