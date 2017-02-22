use strict;
use warnings;

package RPG::Schema::Dungeon_Wall;

use RPG::Position;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Wall');

__PACKAGE__->add_columns(qw/wall_id dungeon_grid_id position_id/);

__PACKAGE__->set_primary_key('wall_id');

__PACKAGE__->belongs_to(
    'position',
    'RPG::Schema::Dungeon_Position',
    { 'foreign.position_id' => 'self.position_id' }
);

__PACKAGE__->belongs_to(
    'dungeon_grid',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

sub opposite_position {
    my $self = shift;

    return RPG::Position->opposite( $self->position->position );
}

sub opposite_sector {
    my $self = shift;

    return RPG::Position->opposite_sector( $self->position->position, $self->dungeon_grid->x, $self->dungeon_grid->y );
}

# Get the wall record on the opposite sector (i.e. the other side of the wall)
sub opposite_wall {
    my $self = shift;

    my ( $x, $y ) = $self->opposite_sector;

    my $dungeon_id = $self->dungeon_grid->dungeon_room->dungeon_id;

    my $schema = $self->result_source->schema;

    my $opposite_sector_record = $schema->resultset('Dungeon_Grid')->find(
        {
            'x'                  => $x,
            'y'                  => $y,
            'dungeon_room.floor' => $self->dungeon_grid->dungeon_room->floor,
            'dungeon_room.dungeon_id' => $dungeon_id,
        },
        {
            join => 'dungeon_room',
        },
    );

    return unless $opposite_sector_record;

    my $opposite_position = $self->opposite_position;

    return $opposite_sector_record->get_wall_at($opposite_position);
}

1;
