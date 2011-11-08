package RPG::Schema::Skill::Strategy;

use Moose::Role;

use feature 'switch';

use Math::Round qw(round);

sub execute {
    my $self = shift;
    my $event = shift;

    my $character = $self->char_with_skill;
    
    given ($event) {
        when ('flee_bonus') {
            return round $self->level + ($character->intelligence / 8);
        }
        
        when ('guard_df') {
            return $self->level;   
        }
    }    
}

1;