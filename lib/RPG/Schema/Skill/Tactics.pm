package RPG::Schema::Skill::Tactics;

use Moose::Role;

use feature 'switch';

use Math::Round qw(round);

sub execute {
    my $self = shift;
    my $event = shift;

    my $character = $self->char_with_skill;
    
    given ($event) {
        when ('opponent_flee') {
            return round $self->level + ($character->intelligence / 4);
        }
        
        when ('guard_af') {
            return $self->level;   
        }
    }    
}

1;