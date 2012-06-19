package RPG::Schema::Skill::Awareness;

use Moose::Role;

use feature 'switch';

use Math::Round qw(round);

sub execute {
    my $self = shift;
    my $event = shift;
    
    my $character = $self->char_with_skill;    
    
    given ($event) {
        when ('chest_trap') {
            return $self->level + round ($character->intelligence / 4);
        }
        
        when ('search_room') {
            return $self->level + round ($character->divinity / 4);
        }
    }
    
}

1;