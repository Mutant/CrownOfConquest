package RPG::Schema::Dungeon_Special_Room;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Special_Room');

__PACKAGE__->add_columns(qw/special_room_id room_type/);

__PACKAGE__->set_primary_key('special_room_id');

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
	
	my $role = $self->get_role_name;
	$self->ensure_class_loaded($role);	
	$role->meta->apply($self);	
}

sub get_role_name {
	my $self = shift;
	
	my $name = $self->room_type;
	
	# Camel case-ify the name
	$name =~ s/(\b|_)(\w)/$1\u$2/g;	
	
	return 'RPG::Schema::Special_Rooms::' . $name;
}

1;