package RPG::Schema::Skill::Negotiation;

use Moose::Role;

use feature 'switch';

use Math::Round qw(round);

sub execute {
    my $self = shift;
    my $event = shift;
    
    my $character = $self->char_with_skill;    
    
    given ($event) {
        when ('town_entrance_tax') {
            return $self->level + round ($character->intelligence / 6);
        }
        
        when ('mayor_overthrow_check') {
            return $self->level;   
        }
    }
    
}

1;