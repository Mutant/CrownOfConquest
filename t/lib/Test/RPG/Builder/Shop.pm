use strict;
use warnings;

package Test::RPG::Builder::Shop;

sub build_shop {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $shop = $schema->resultset('Shop')->create(
        {
            town_id => $params{town_id} || 1,
            status  => $params{status}  || 'Open',
        }
    );

    return $shop;
}

1;
