use strict;
use warnings;

package Test::RPG::NewDay::Town_Loyalty;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

use RPG::NewDay::Action::Town_Loyalty;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;

    $self->{action} = RPG::NewDay::Action::Town_Loyalty->new( context => $self->{mock_context} );
}

sub test__calculate_connected_sectors : Tests(25) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 5, 'y_size' => 5 );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );
    $kingdom->capital( $town->id );
    $kingdom->update;

    for my $x ( 1 .. 5 ) {
        next if $x == 3;

        for my $y ( 1 .. 5 ) {
            my $land = $self->{schema}->resultset('Land')->find( { x => $x, y => $y } );
            $land->kingdom_id( $kingdom->id );
            $land->update;
        }
    }

    my $sectors_rs = $kingdom->sectors;

    $sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my @sectors = $sectors_rs->all;

    # WHEN
    my $connected = $self->{action}->_calculate_connected_sectors( $kingdom, @sectors );

    # THEN
    for my $x ( 1 .. 5 ) {
        my $expected = $x < 3 ? 1 : undef;

        for my $y ( 1 .. 5 ) {
            is( $connected->{$x}{$y}, $expected, "Correct connected value for $x, $y" );
        }
    }

}

1;
