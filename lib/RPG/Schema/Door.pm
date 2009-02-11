use strict;
use warnings;

package RPG::Schema::Door;

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

my %door_opposites = (
    'top'    => 'bottom',
    'bottom' => 'top',
    'left'   => 'right',
    'right'  => 'left',
);

sub opposite_position {
    my $self = shift;
    
    return $door_opposites{$self->position->position};
}

# TODO: move to door schema
sub opposite_sector {
    my $self = shift;

    my %door_position_modifier = (
        'top'    => { y => -1 },
        'bottom' => { y => 1 },
        'left'   => { x => -1 },
        'right'  => { x => 1 },
    );

    my $door_x = $self->dungeon_grid->x + ( $door_position_modifier{ $self->position->position }{x} || 0 );
    my $door_y = $self->dungeon_grid->y + ( $door_position_modifier{ $self->position->position }{y} || 0 );

    return ( $door_x, $door_y );
}

1;
