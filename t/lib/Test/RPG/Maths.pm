use strict;
use warnings;

package Test::RPG::Maths;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

use RPG::Maths;

sub startup : Test(startup) {
    my $self = shift;

    $self->{dice} = Test::MockObject::Extra->new();
    $self->{dice}->fake_module(
        'Games::Dice::Advanced',
        roll => sub { $self->{roll_result} || 0 },
    );
}

sub shutdown : Test(shutdown) {
    my $self = shift;

    $self->unmock_dice;
}

sub test_weighted_random_number : Tests(1) {
    my $self = shift;

    my @numbers = 1 .. 19;

    $self->{roll_result} = 1;
    is( RPG::Maths->weighted_random_number(@numbers), 1 );
}

sub test_weighted_random_number_2 : Tests(1) {
    my $self = shift;

    my @numbers = qw(1 2 3 4 5);

    $self->{roll_result} = 105;
    is( RPG::Maths->weighted_random_number(@numbers), 3 );
}

sub test_calculate_weights : Tests(3) {
    my $self = shift;

    my @numbers = 1 .. 3;

    my ( $cumulative_chance, %weights ) = RPG::Maths::_calculate_weights(@numbers);
    my %a;

    foreach my $number ( sort keys %weights ) {
        $a{ $weights{$number} } = $number;
    }

    my $last = 0;
    my %chances;
    foreach my $number ( sort { $a <=> $b } keys %a ) {
        $chances{$number} = ( $a{$number} - $last ) / $cumulative_chance * 100;
        $last = $a{$number};
    }

    is( $chances{1} > 50, 1, "1 chance above 50%" );
    is( $chances{2} > 25, 1, "2 chance above 25%" );
    is( $chances{3} > 18, 1, "3 chance above 18%" );
}

1;
