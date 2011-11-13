package RPG::Schema::Skill::Berserker_Rage;

use Moose::Role;

use Games::Dice::Advanced;
use Math::Round qw(round);

use RPG::Combat::SkillActionResult;

sub execute {
    my $self = shift;
    my $event = shift;
    my $character = shift // $self->char_with_skill;
    
    return unless $event eq 'combat';
  
    my %results = (
        fired => 0,
    );

    my $has_berserk = $character->search_related('character_effects',
        {
            'effect.effect_name' => 'Berserk',
            'effect.time_left' => {'>=', 1},
        },
        {
            join => 'effect',
        }
    )->count;
    
    return %results if $has_berserk;
    
    my $chance = $self->level * 3 + ($character->constitution / 5);

    if (Games::Dice::Advanced->roll('1d100') <= $chance) {
        $results{fired} = 1;
        $results{factor_changed} = 1;
        
        my $duration = Games::Dice::Advanced->roll('1d6') + round ($self->level / 3) + 1;
        
        $self->result_source->schema->resultset('Effect')->create_effect({
            effect_name => 'Berserk',
            target => $character,
            modifier => $self->level + 5,
            combat => 1,
            modified_state => 'damage',
            duration => $duration,
        });
        
        my $action = RPG::Combat::SkillActionResult->new(
            skill => 'berserker_rage',
            duration => $duration,
            attacker => $character,
            defender => $character,
        );
        
        $results{message} = $action;           
    }
    
    return %results;
}

1;