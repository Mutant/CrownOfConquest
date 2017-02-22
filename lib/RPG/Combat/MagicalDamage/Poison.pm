package RPG::Combat::MagicalDamage::Poison;

use strict;
use warnings;

use Games::Dice::Advanced;

sub apply {
    my $self   = shift;
    my %params = @_;

    my $magical_damage_result = RPG::Combat::MagicalDamageResult->new(
        type => 'Poison',
    );

    if ( $params{opponent}->resistance_roll('Poison') ) {
        $magical_damage_result->resisted(1);
        return $magical_damage_result;
    }

    unless ( $params{opponent}->is_dead ) {
        my $modifier = $params{level};
        my $duration = int( ( $params{level} + 3 ) / 2 );

        $params{schema}->resultset('Effect')->create_effect(
            {
                target         => $params{opponent},
                effect_name    => 'Poisoned',
                duration       => $duration,
                modifier       => $modifier,
                combat         => 1,
                modified_state => 'poison',
            }
        );

        $magical_damage_result->duration($duration);
        $magical_damage_result->effect('poisoned');
    }

    return $magical_damage_result;
}

1;
