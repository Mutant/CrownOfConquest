use strict;
use warnings;

package Test::RPG::Builder::Effect;

sub build_effect {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $effect = $schema->resultset('Effect')->create(
        {
            effect_name => 'foo',
            time_left   => 1,
            modifier    => 1,
            combat      => 1,
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
    
    return $effect;
}

1;
