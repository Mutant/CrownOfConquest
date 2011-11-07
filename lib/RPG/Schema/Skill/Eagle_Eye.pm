package RPG::Schema::Skill::Eagle_Eye;

use Moose::Role;

use feature 'switch';

sub execute {
    my $self = shift;
    my $event = shift;
    
    given ($event) {
        when ('critical_hit_chance') {
            return $self->level;
        }
    }
    
}

1;