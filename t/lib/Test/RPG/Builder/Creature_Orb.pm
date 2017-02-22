use strict;
use warnings;

package Test::RPG::Builder::Creature_Orb;

sub build_orb {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $orb = $schema->resultset('Creature_Orb')->create(
        {
            level   => 1,
            name    => 'Test Orb',
            land_id => $params{land_id},
        }
    );

    return $orb;
}

1;
