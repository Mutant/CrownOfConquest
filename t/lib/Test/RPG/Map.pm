use strict;
use warnings;

package Test::RPG::Maths;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

use RPG::Map;

sub test_get_overlapping_sectors : Tests(no_plan) {
    my $self = shift;
    
    # GIVEN
    my @first_square = (
        {
            x => 8,
            y => 7,
        },
        {
            x => 14,
            y => 13,
        }
    );

    my @second_square = (
        {
            x => 7,
            y => 2,
        },
        {
            x => 9,
            y => 7,
        }
    );
    
    # WHEN
    my @overlapping_sqaures = RPG::Map->get_overlapping_sectors(\@first_square, \@second_square);       
    
    is(scalar @overlapping_sqaures, 2, "Should be 2 squares overlapping");
    
}

1;