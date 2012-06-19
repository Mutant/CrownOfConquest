package RPG::Schema::Skill::Shield_Bash;

use Moose::Role;

use Games::Dice::Advanced;
use Math::Round qw(round);

use RPG::Combat::SkillActionResult;

sub needs_defender { 1 };

sub execute {
    my $self = shift;
    my $event = shift;
    my $character = shift // $self->char_with_skill;
    my $defender = shift;
    
    return unless $event eq 'combat';
  
    my %results = (
        fired => 0,
    );
    
    return %results unless $character->last_combat_action eq 'Attack';

    my $has_shield = $character->search_related(
        'items',
        {
            'category.item_category' => 'Shield',
            'equip_place_id'         => { '!=', undef },
        },
        {
            'join'     => { 'item_type' => 'category', },
        },
    )->count;
    
    return %results unless $has_shield;    
    
    my $chance = $self->level * 3 + ($character->strength / 5);

    if (Games::Dice::Advanced->roll('1d100') <= $chance) {
        $results{fired} = 1;
        
        my $damage = Games::Dice::Advanced->roll('1d6') + round $self->level / 2;
        
        $defender->hit($damage, $character);  
        
        my $action = RPG::Combat::ActionResult->new(
            special_weapon => 'Shield Bash',
            attacker => $character,
            defender => $defender,
            damage => $damage,
        );
        
        $results{message} = $action;           
    }
    
    return %results;
}

1;