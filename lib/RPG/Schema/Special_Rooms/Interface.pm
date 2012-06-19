package RPG::Schema::Special_Rooms::Interface;
# Interface for special room roles

use Moose::Role;

# Defined by the role
requires qw/generate_special remove_special is_active/;

after 'remove_special' => sub {
    my $self = shift;
    
    $self->special_room_id(undef);
    $self->update;   
};

1;