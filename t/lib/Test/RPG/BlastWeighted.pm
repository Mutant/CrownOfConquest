use strict;
use warnings;

package Test::RPG::BlastWeighted;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use RPG::Maths;

sub test : Tests(10000) {
    my $self = shift;

    for ( 1 .. 5000 ) {
        my $num = RPG::Maths->weighted_random_number( 1 .. 20 );
        cmp_ok( $num, '>=', 1,  "Number within lower bound" );
        cmp_ok( $num, '<=', 20, "Number within upper bound" );
    }
}

1;
