use strict;
use warnings;

package RPG::Schema::Dungeon_Room;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Room');

__PACKAGE__->add_columns(qw/dungeon_room_id dungeon_id floor special_room_id/);

__PACKAGE__->set_primary_key('dungeon_room_id');

__PACKAGE__->belongs_to(
    'dungeon',
    'RPG::Schema::Dungeon',
    { 'foreign.dungeon_id' => 'self.dungeon_id' }
);

__PACKAGE__->has_many(
    'sectors',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_room_id' => 'self.dungeon_room_id' }
);

__PACKAGE__->belongs_to(
    'special_room',
    'RPG::Schema::Dungeon_Special_Room',
    'special_room_id',
);

sub insert {
	my ( $self, @args ) = @_;
	
	$self->next::method(@args);
	
	$self->_apply_role;
}

sub inflate_result {
    my $pkg = shift;

    my $self = $pkg->next::method(@_);

    $self->_apply_role;

    return $self;
}

sub _apply_role {
	my $self = shift;
	my $special_room_type = shift;
	
	my $role = $self->get_role_name($special_room_type);
	return unless $role;
	
	$self->ensure_class_loaded($role);	
	$role->meta->apply($self);	
}

sub get_role_name {
	my $self = shift;
	
	return unless $self->special_room_id;

	my $special_room = shift || $self->special_room;
	
	return unless $special_room;
	
	my $name = $special_room->room_type;
	
	# Camel case-ify the name
	$name =~ s/(\b|_)(\w)/$1\u$2/g;	
	
	return 'RPG::Schema::Special_Rooms::' . $name;
}

# Turn a dungeon room into a special dungeon room
sub make_special {
    my $self = shift;
    my $special_room_type = shift;
    
    $self->special_room_id($special_room_type->id);
    $self->update;
    
    $self->_apply_role($special_room_type);
    $self->generate;
}

sub connected_to_room {
    my $self = shift;
    my $room_id = shift;
    
    return $self->{connected_to_room}{$room_id} if defined $self->{connected_to_room}{$room_id};
        
    return 0 if $room_id == $self->dungeon_room_id;
        
    my @sectors = $self->result_source->schema->resultset('Dungeon_Grid')->search(
        {
            dungeon_room_id => $self->id,
        },
        {
            prefetch => {'doors' => 'position'},
        }
    );
    
    my $connected = 0;

    SECTOR: foreach my $sector (@sectors) {
        foreach my $door ($sector->doors) {
            my ($sector_to_check_x, $sector_to_check_y) = RPG::Position->opposite_sector($door->position->position, $sector->x, $sector->y);
                        
            my $sector_to_check = $self->result_source->schema->resultset('Dungeon_Grid')->find(
                {
                    x => $sector_to_check_x,
                    y => $sector_to_check_y,
                    'dungeon_room.dungeon_id' => $self->dungeon_id,
                    'dungeon_room.floor' => $self->floor,
                },
                {
                    join => 'dungeon_room',
                }
            );
            
            if ($sector_to_check->dungeon_room_id == $room_id) {
                $connected = 1;
                last SECTOR;
            }
        }
    }
    
    $self->{connected_to_room}{$room_id} = $connected;
    
    return $connected;
}

1;