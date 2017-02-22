package RPG::Schema::Skill::War_Cry;

use Moose::Role;

use Games::Dice::Advanced;
use Math::Round qw(round);

use RPG::Combat::SkillActionResult;

sub needs_defender { 0 }

sub execute {
    my $self      = shift;
    my $event     = shift;
    my $character = shift // $self->char_with_skill;

    return unless $event eq 'combat';

    my %results = (
        fired => 0,
    );

    return %results unless $character->last_combat_action eq 'Attack';

    my $has_war_cry = $character->search_related( 'character_effects',
        {
            'effect.effect_name' => 'War Cry',
            'effect.time_left' => { '>=', 1 },
        },
        {
            join => 'effect',
        }
    )->count;

    return %results if $has_war_cry;

    my $chance = $self->level * 3 + ( $character->divinity / 5 );

    if ( Games::Dice::Advanced->roll('1d100') <= $chance ) {
        $results{fired}          = 1;
        $results{factor_changed} = 1;

        my $duration = 1;

        $self->result_source->schema->resultset('Effect')->create_effect( {
                effect_name    => 'War Cry',
                target         => $character,
                modifier       => $self->level + 5,
                combat         => 1,
                modified_state => 'attack_factor',
                duration       => $duration,
        } );

        my $action = RPG::Combat::SkillActionResult->new(
            skill    => 'war_cry',
            duration => $duration,
            attacker => $character,
            defender => $character,
        );

        $results{message} = $action;
    }

    return %results;
}

1;
