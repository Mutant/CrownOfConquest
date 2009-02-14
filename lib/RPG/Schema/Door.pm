use strict;
use warnings;

package RPG::Schema::Door;

use RPG::Position;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Door');

__PACKAGE__->add_columns(qw/door_id position_id dungeon_grid_id/);

__PACKAGE__->set_primary_key('door_id');

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
    
    return RPG::Position->opposite($self->position->position);
}

sub opposite_sector {
    my $self = shift;

    return RPG::Position->opposite_sector($self->position->position, $self->dungeon_grid->x, $self->dungeon_grid->y);
}

1;
