use strict;
use warnings;

package Test::RPG::Builder::Day;

sub build_day {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $day = $schema->resultset('Day')->create( 
        { 
            day_number => $params{day_number} || int rand 1000,
            turns_used => $params{turns_used} || 100, 
        } 
    );

    return $day;
}

1;