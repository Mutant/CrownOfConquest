use strict;
use warnings;

package Test::RPG::Builder::Effect;

sub build_effect {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $effect = $schema->resultset('Effect')->create(
        {
            effect_name => $params{effect_name} || 'foo',
            time_left => 1,
            modifier => $params{modifier} // 1,
            combat => 1,
            modified_stat => $params{modified_stat} || 'stat',
        }
    );

    if ( $params{creature_id} ) {
        my $creature_effect = $schema->resultset('Creature_Effect')->create(
            {
                creature_id => $params{creature_id},
                effect_id   => $effect->id,
            }
        );
    }

    if ( $params{character_id} ) {
        my $creature_effect = $schema->resultset('Character_Effect')->create(
            {
                character_id => $params{character_id},
                effect_id    => $effect->id,
            }
        );
    }

    return $effect;
}

1;
