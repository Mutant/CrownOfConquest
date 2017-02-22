use strict;
use warnings;

package Test::RPG::Schema::Player;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Player;

use DateTime;

sub test_has_ips_in_common_with_common_ips : Tests(1) {
    my $self = shift;

    # GIVEN
    my $player1 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 1 );
    my $player2 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 2 );

    $player1->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 9 ),
        }
    );

    $player1->add_to_logins(
        {
            ip => '10.10.10.11',
            login_date => DateTime->now->subtract( days => 3 ),
        }
    );

    $player2->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 5 ),
        }
    );

    $player2->add_to_logins(
        {
            ip => '10.10.10.12',
            login_date => DateTime->now->subtract( days => 1 ),
        }
    );

    $self->{config}{ip_coop_window} = 10;
    $self->{config}{check_for_coop} = 1;

    # WHEN
    my $res = $player1->has_ips_in_common_with($player2);

    # THEN
    is( $res, 1, "Players have ips in common" );
}

sub test_has_ips_in_common_with_no_common_ips_in_window : Tests(1) {
    my $self = shift;

    # GIVEN
    my $player1 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 1 );
    my $player2 = Test::RPG::Builder::Player->build_player( $self->{schema}, name => 2 );

    $player1->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 11 ),
        }
    );

    $player1->add_to_logins(
        {
            ip => '10.10.10.11',
            login_date => DateTime->now->subtract( days => 9 ),
        }
    );

    $player1->add_to_logins(
        {
            ip => '10.10.10.15',
            login_date => DateTime->now->subtract( days => 3 ),
        }
    );

    $player2->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 5 ),
        }
    );

    $player2->add_to_logins(
        {
            ip => '10.10.10.15',
            login_date => DateTime->now->subtract( days => 12 ),
        }
    );

    $self->{config}{ip_coop_window} = 10;
    $self->{config}{check_for_coop} = 1;

    # WHEN
    my $res = $player1->has_ips_in_common_with($player2);

    # THEN
    is( $res, 0, "Players don't have ips in common" );
}

1;
