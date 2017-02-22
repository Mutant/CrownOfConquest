use strict;
use warnings;

package Test::RPG::C::Panel;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Combat_Log;
use Test::RPG::Builder::Party;

use DateTime;
use Data::Dumper;

use RPG::C::Panel;

sub test_messsages : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, last_action => DateTime->now->subtract( minutes => 10 ) );
    my $combat_log = Test::RPG::Builder::Combat_Log->build_log( $self->{schema}, opp_1 => $party,
        encounter_started => DateTime->now->subtract( minutes => 7 ),
        encounter_ended   => DateTime->now->subtract( minutes => 6 ),
    );

    $self->{config}->{online_threshold} = 5;

    $self->{stash}{party} = $party;

    # WHEN
    RPG::C::Panel->messages( $self->{c} );

    # THEN
    is( scalar @{ $self->{stash}->{messages} }, 1, "1 message added" );
}

1;
