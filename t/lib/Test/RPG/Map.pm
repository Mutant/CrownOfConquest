use strict;
use warnings;

package Test::RPG::Map;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

use RPG::Map;

sub test_get_overlapping_sectors : Tests(1) {
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
    my @overlapping_sqaures = RPG::Map->get_overlapping_sectors( \@first_square, \@second_square );

    is( scalar @overlapping_sqaures, 2, "Should be 2 squares overlapping" );

}

sub test_surrounds_by_range : Tests(6) {
    my $self = shift;

    # GIVEN
    my %tests = (
        range_of_0 => {
            x_base         => 5,
            y_base         => 5,
            x_range        => 0,
            y_range        => 0,
            expected_start => {
                x => 5,
                y => 5,
            },
            expected_end => {
                x => 5,
                y => 5,
            },
        },
        range_of_3 => {
            x_base         => 5,
            y_base         => 5,
            x_range        => 3,
            y_range        => 3,
            expected_start => {
                x => 2,
                y => 2,
            },
            expected_end => {
                x => 8,
                y => 8,
            },
        },
        aysmetric_range => {
            x_base         => 5,
            y_base         => 5,
            x_range        => 3,
            y_range        => 1,
            expected_start => {
                x => 2,
                y => 4,
            },
            expected_end => {
                x => 8,
                y => 6,
            },
        },
    );

    # WHEN
    my %results;
    while ( my ( $test_name, $test_data ) = each %tests ) {
        $results{$test_name} = [ RPG::Map->surrounds_by_range(
                $test_data->{x_base},
                $test_data->{y_base},
                $test_data->{x_range},
                $test_data->{y_range},
        ) ];
    }

    # THEN
    while ( my ( $test_name, $test_data ) = each %tests ) {
        is_deeply( $results{$test_name}->[0], $test_data->{expected_start}, "Start point as expected ($test_name)" );
        is_deeply( $results{$test_name}->[1], $test_data->{expected_end}, "End point as expected ($test_name)" );
    }
}

sub test_get_direction_to_point : Tests {
    my $self = shift;

    # GIVEN
    my @tests = (
        {
            point1 => {
                x => 1,
                y => 1,
            },
            point2 => {
                x => 2,
                y => 1,
            },
            expected_result => 'East',
        },
        {
            point1 => {
                x => 2,
                y => 1,
            },
            point2 => {
                x => 1,
                y => 1,
            },
            expected_result => 'West',
        },
        {
            point1 => {
                x => 1,
                y => 1,
            },
            point2 => {
                x => 2,
                y => 2,
            },
            expected_result => 'South East',
        },
        {
            point1 => {
                x => 1,
                y => 1,
            },
            point2 => {
                x => 10,
                y => 10,
            },
            expected_result => 'South East',
        },
        {
            point1 => {
                x => 8,
                y => 1,
            },
            point2 => {
                x => 10,
                y => 10,
            },
            expected_result => 'South',
        },

    );

    # WHEN
    my @results;
    foreach my $test_data (@tests) {
        push @results, RPG::Map->get_direction_to_point(
            $test_data->{point1},
            $test_data->{point2},
        );
    }

    # THEN
    my $count = 0;
    foreach my $test_data (@tests) {
        is( $results[$count], $test_data->{expected_result}, "Expected result returned" );
        $count++;
    }
}

sub test_compile_rows_and_columns : Tests(3) {
    my $self = shift;

    # GIVEN
    no warnings 'qw';
    my @sectors = qw/5,1 6,1 7,1 7,2 7,3/;

    # WHEN
    my @results = RPG::Map->compile_rows_and_columns(@sectors);

    # THEN
    is( scalar @results, 2, "1 col and 1 row returned" );

    my $expected_row = [qw/5,1 6,1/];
    is_deeply( $results[1], $expected_row, "Row is correct" );

    my $expected_col = [qw/7,1 7,2 7,3/];
    is_deeply( $results[0], $expected_col, "Col is correct" );
}

1;
