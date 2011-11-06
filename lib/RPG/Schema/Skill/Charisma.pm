package RPG::Schema::Skill::Charisma;

use Moose::Role;

use Math::Round;

use feature 'switch';

sub execute {
    my $self = shift;
    my $event = shift;
      
    my $character = $self->char_with_skill;
    
    given ($event) {
        when ('mayor_approval') {
            return round ($self->level / 2);
        }
        
        when ('election') {
            return $self->level * 2 + round ($character->intelligence / 2);    
        }
        
        when ('kingdom_loyalty') {
            return round ($self->level / 2);
        }
    }
    
}

1;