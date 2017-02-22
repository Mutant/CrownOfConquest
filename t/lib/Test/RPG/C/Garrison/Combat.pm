use strict;
use warnings;

package Test::RPG::C::Garrison::Combat;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Combat_Log;

sub combat_startup : Test(startup => 1) {
    my $self = shift;

    use_ok('RPG::C::Garrison::Combat');
}

sub test_attack : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, land_id => $party->land_id );

    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Garrison::Combat->attack( $self->{c} );

    # THEN
    is( $self->{stash}{in_combat_with_garrison}->id, $garrison->id, "Garrison added into stash" );
    is( $self->{stash}{party_initiated}, 1, "Party initiated value recorded in stash" );

    $party->discard_changes;
    is( $party->in_combat_with, $garrison->id, "Party now in combat with garrison" );
    is( $party->combat_type, 'garrison', "Combat type correct" );

}

sub test_attack_garrison_too_low_level : Tests(3) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 10, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, land_id => $party->land_id, character_level => 5, character_count => 2 );

    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    $self->{config}{max_party_garrison_level_difference} = 4;

    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Garrison::Combat->attack( $self->{c} );

    # THEN
    is( $self->{stash}{error}, "The garrison is too weak to attack", "Error message set" );
    is( $self->{stash}{in_combat_with_garrison}, undef, "Garrison not added into stash" );

    $party->discard_changes;
    is( $party->in_combat_with, undef, "Party not in combat with garrison" );
}

sub test_attack_garrison_too_low_level_but_building_in_sector : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 10, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, land_id => $party->land_id, character_level => 5, character_count => 2 );

    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $party->land_id );

    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    $self->{config}{max_party_garrison_level_difference} = 4;

    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Garrison::Combat->attack( $self->{c} );

    # THEN
    $party->discard_changes;
    is( $party->in_combat_with, $garrison->id, "Party now in combat with garrison" );
    is( $party->combat_type, 'garrison', "Combat type correct" );
}

sub test_attack_garrison_too_many_recent_battles : Tests(3) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 5, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, land_id => $party->land_id, character_level => 5, character_count => 2 );

    Test::RPG::Builder::Combat_Log->build_log( $self->{schema}, opp_1 => $party, opp_2 => $garrison );
    Test::RPG::Builder::Combat_Log->build_log( $self->{schema}, opp_1 => $party, opp_2 => $garrison );
    Test::RPG::Builder::Combat_Log->build_log( $self->{schema}, opp_1 => $party, opp_2 => $garrison );

    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Garrison::Combat->attack( $self->{c} );

    # THEN
    is( $self->{stash}{error}, "This garrison has been attacked too many times recently", "Error message set" );
    is( $self->{stash}{in_combat_with_garrison}, undef, "Garrison not added into stash" );

    $party->discard_changes;
    is( $party->in_combat_with, undef, "Party not in combat with garrison" );
}

1;
