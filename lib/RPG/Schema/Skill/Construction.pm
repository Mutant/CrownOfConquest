package RPG::Schema::Skill::Construction;

use Moose::Role;

use feature 'switch';

sub execute {
    my $self = shift;
    my $event = shift;
      
    my $character = $self->char_with_skill;
    
    given ($event) {
        when ('building_cost') {
            return $self->level * 2;
        }
    }
    
}

1;