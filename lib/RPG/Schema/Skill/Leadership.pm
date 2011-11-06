package RPG::Schema::Skill::Leadership;

use Moose::Role;

use Math::Round;

use feature 'switch';

sub execute {
    my $self = shift;
    my $event = shift;
      
    my $character = $self->char_with_skill;
    
    given ($event) {
        when ('town_peasant_tax') {
            return $self->level * 2;
        }
        
        when ('kingdom_quests_allowed') {
            return $self->level;   
        }
    }
    
}

1;