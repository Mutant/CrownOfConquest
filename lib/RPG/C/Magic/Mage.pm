package RPG::C::Magic::Mage;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;

sub energy_beam : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $dice_count = int $character->level / 5 + 1;

    my $beam = Games::Dice::Advanced->roll( $dice_count . "d6" );

    my $target_creature = $c->stash->{creatures}{$target};
    $target_creature->change_hit_points( -$beam );
    $target_creature->update;

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/damage.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Energy Beam',
                    damage     => $beam,
                    effect     => 'zapping',
                },
                return_output => 1,
            }
        ]
    );
}

sub confuse : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $defence_modifier = 0 - $character->level;
    my $duration = 2 * ( int $character->level / 2 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'creature',
                target_id      => $target,
                effect_name    => 'Confused',
                duration       => $duration,
                modifier       => $defence_modifier,
                combat         => 1,
                modified_state => 'defence_factor',
            }
        ]
    );

    my $target_creature = $c->stash->{creatures}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Confuse',
                    duration  => $duration,
                    effect => 'confusing',
                },
                return_output => 1,
            }
        ]
    );
}

sub weaken : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $modifier = 0 - $character->level;
    my $duration = 2 * ( int $character->level / 3 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'creature',
                target_id      => $target,
                effect_name    => 'Weakened',
                duration       => $duration,
                modifier       => $modifier,
                combat         => 1,
                modified_state => 'damage',
            }
        ]
    );

    my $target_creature = $c->stash->{creatures}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Weaken',
                    duration  => $duration,
                    effect => 'weakening',
                },
                return_output => 1,
            }
        ]
    );
}

sub curse : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $modifier = 0 - $character->level;
    my $duration = 2 * ( int $character->level / 4 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'creature',
                target_id      => $target,
                effect_name    => 'Cursed',
                duration       => $duration,
                modifier       => $modifier,
                combat         => 1,
                modified_state => 'attack_factor',
            }
        ]
    );
    

    my $target_creature = $c->stash->{creatures}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Curse',
                    duration  => $duration,
                    effect => 'cursing',
                },
                return_output => 1,
            }
        ]
    );    
}

sub slow : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $duration = 2 * ( int $character->level / 3 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'creature',
                target_id      => $target,
                effect_name    => 'Slowed',
                duration       => $duration,
                modifier       => 1,
                combat         => 1,
                modified_state => 'attack_frequency',
            }
        ]
    );

    my $target_creature = $c->stash->{creatures}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Slow',
                    duration  => $duration,
                    effect => 'slowing',
                },
                return_output => 1,
            }
        ]
    );   
}

sub entangle : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $duration = 3 + ( int $character->level / 5 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'creature',
                target_id      => $target,
                effect_name    => 'Entangled',
                duration       => $duration,
                modifier       => $duration,
                combat         => 1,
                modified_state => 'attack_frequency',
            }
        ]
    );

    my $target_creature = $c->stash->{creatures}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Entangle',
                    duration  => $duration,
                    effect => 'entangling',
                },
                return_output => 1,
            }
        ]
    );   
}

sub flame : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $dice_count = int $character->level / 3 + 1;

    my $flame = Games::Dice::Advanced->roll( $dice_count . "d10" );

    my $target_creature = $c->stash->{creatures}{$target};
    $target_creature->change_hit_points( -$flame );
    $target_creature->update;
    
     return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/damage.html',
                params   => {
                    caster     => $character,
                    target     => $target_creature,
                    spell_name => 'Flame',
                    damage     => $flame,
                    effect     => 'frying',
                },
                return_output => 1,
            }
        ]
    );
}

1;
