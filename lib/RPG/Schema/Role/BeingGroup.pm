package RPG::Schema::Role::BeingGroup;

use Moose::Role;

use Carp;

requires qw/members number_alive after_land_move/;

sub move_to {
    my $self = shift;
    my $sector = shift;
    
    return unless $sector;
    
    if ($sector->isa('RPG::Schema::Land')) {
        $self->land_id($sector->id);
        $self->after_land_move($sector);
    }
    elsif ($sector->isa('RPG::Schema::Dungeon_Grid')) {
        $self->dungeon_grid_id($sector->id);   
    }
    else {        
        confess "don't know how to deal with sector: $sector";
    }       
}

1;