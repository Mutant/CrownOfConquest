use strict;
use warnings;

package Test::RPG::Builder::Road;

sub build_road {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    return $schema->resultset('Road')->create(
        {
            land_id  => $params{land_id},
            position => $params{position},
        }
    );

}

1;
