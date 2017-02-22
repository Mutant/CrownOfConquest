package Test::RPG::ResultSet::Land;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Data::Dumper;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Town;

sub test_search_for_adjacent_sectors_basic : Tests(1) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    # WHEN
    my @sectors = $self->{schema}->resultset('Land')->search_for_adjacent_sectors(
        $land[4]->x,
        $land[4]->y,
        3,
        3,
    );

    # THEN
    is( scalar @sectors, 8, "Adjacent sectors returned" );
}

sub test_search_for_adjacent_sectors_blocked_sectors : Tests(1) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, land_id => $land[0]->id );
    Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[1]->id );

    # WHEN
    my @sectors = $self->{schema}->resultset('Land')->search_for_adjacent_sectors(
        $land[4]->x,
        $land[4]->y,
        3,
        3,
        1,
    );

    # THEN
    is( scalar @sectors, 6, "Adjacent sectors returned" );
}

1;
