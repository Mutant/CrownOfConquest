package RPG::C::Magic::Priest;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;

sub heal : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $dice_count = int $character->level / 5 + 1;

    my $heal = Games::Dice::Advanced->roll( $dice_count . "d6" );

    my $target_char = $c->stash->{characters}{$target};
    $target_char->change_hit_points($heal);
    $target_char->update;

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/damage.html',
                params   => {
                    caster     => $character,
                    target     => $target_char,
                    spell_name => 'Heal',
                    damage     => $heal,
                    effect     => 'healing',
                },
                return_output => 1,
            }
        ]
    );
}

sub shield : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $shield_modifier = $character->level;
    my $duration = 2 * ( int $character->level / 5 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'character',
                target_id      => $target,
                effect_name    => 'Shield',
                duration       => $duration,
                modifier       => $shield_modifier,
                combat         => 1,
                modified_state => 'defence_factor',
            }
        ]
    );

    my $target_char = $c->stash->{characters}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_char,
                    spell_name => 'Shield',
                    duration   => $duration,
                    effect     => 'protecting',
                },
                return_output => 1,
            }
        ]
    );
}

sub bless : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $modifier = $character->level;
    my $duration = 1 + ( int $character->level / 3 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'character',
                target_id      => $target,
                effect_name    => 'Bless',
                duration       => $duration,
                modifier       => $modifier,
                combat         => 1,
                modified_state => 'attack_factor',
            }
        ]
    );

    my $target_char = $c->stash->{characters}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_char,
                    spell_name => 'Bless',
                    duration   => $duration,
                    effect     => 'blessing',
                },
                return_output => 1,
            }
        ]
    );
}

sub blades : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $modifier = $character->level;
    my $duration = 2 + ( int $character->level / 3 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'character',
                target_id      => $target,
                effect_name    => 'Blades',
                duration       => $duration,
                modifier       => $modifier,
                combat         => 1,
                modified_state => 'damage',
            }
        ]
    );

    my $target_char = $c->stash->{characters}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_char,
                    spell_name => 'Blades',
                    duration   => $duration,
                    effect     => 'enhancing his weapon',
                },
                return_output => 1,
            }
        ]
    );
}

sub haste : Private {
    my ( $self, $c, $character, $target ) = @_;

    my $duration = 2 * ( int $character->level / 3 + 1 );

    $c->forward(
        '/magic/create_effect',
        [
            {
                target_type    => 'character',
                target_id      => $target,
                effect_name    => 'Haste',
                duration       => $duration,
                modifier       => 0.5,
                combat         => 1,
                modified_state => 'attack_frequency',
            }
        ]
    );

    my $target_char = $c->stash->{characters}{$target};

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'magic/effect.html',
                params   => {
                    caster     => $character,
                    target     => $target_char,
                    spell_name => 'Haste',
                    duration   => $duration,
                    effect     => 'speeding his attack',
                },
                return_output => 1,
            }
        ]
    );
}

1;
