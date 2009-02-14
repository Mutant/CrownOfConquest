use strict;
use warnings;

package RPG::Schema::Dungeon_Grid;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Grid');

__PACKAGE__->add_columns(qw/dungeon_grid_id x y dungeon_room_id/);

__PACKAGE__->set_primary_key('dungeon_grid_id');

__PACKAGE__->has_many(
    'doors',
    'RPG::Schema::Door',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->has_many(
    'walls',
    'RPG::Schema::Dungeon_Wall',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->belongs_to(
    'dungeon_room',
    'RPG::Schema::Dungeon_Room',
    { 'foreign.dungeon_room_id' => 'self.dungeon_room_id' }
);

__PACKAGE__->has_many(
    'mapped_dungeon_grid',
    'RPG::Schema::Mapped_Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

sub sides_with_walls {
    my $self = shift;
    
    my @walls = $self->walls;
    
    my @sides_with_walls;
    
    foreach my $wall (@walls) {
        push @sides_with_walls, $wall->position->position;
    }
    
    return @sides_with_walls;    
}

sub has_wall {
    my $self = shift;
    my $wall_side = shift;
    
    return grep { $wall_side eq $_ } $self->sides_with_walls;
}

1;