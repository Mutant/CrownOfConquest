use strict;
use warnings;

package Test::RPG::NewDay::Garrison;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;
use DateTime;

use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Kingdom;

use RPG::NewDay::Action::Garrison;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;

    $self->{action} = RPG::NewDay::Action::Garrison->new( context => $self->{mock_context} );
}

sub test_garrison_claims_land : Tests(27) {
    my $self = shift;

    # GIVEN
    my @land    = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id, kingdom_id => $kingdom->id );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id,
        established => DateTime->now->subtract( days => 3 ), );

    $garrison->claim_land_order(1);
    $garrison->update;

    # WHEN
    $self->{action}->run();

    # THEN
    foreach my $land (@land) {
        $land->discard_changes;
        is( $land->kingdom_id, $kingdom->id, "Land now claimed by kingdom" );
        is( $land->claimed_by_id, $garrison->id, "Garrison claimed sector " . $land->id );
        is( $land->claimed_by_type, 'garrison', "Claimed by type correct for sector " . $land->id );
    }
}

sub test_garrison_unclaims_land : Tests(27) {
    my $self = shift;

    # GIVEN
    my @land    = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id, kingdom_id => $kingdom->id );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id,
        established => DateTime->now->subtract( days => 3 ), );

    $garrison->claim_land;

    $garrison->claim_land_order(0);
    $garrison->update;

    # WHEN
    $self->{action}->run();

    # THEN
    foreach my $land (@land) {
        $land->discard_changes;
        is( $land->kingdom_id, $kingdom->id, "Land still claimed by kingdom" );
        is( $land->claimed_by_id, undef, "Garrison no longer claims sector " . $land->id );
        is( $land->claimed_by_type, undef, "No claimed by type for sector " . $land->id );
    }
}

sub test_garrison_reclaims_land_when_party_changes_allegiance : Tests(27) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id, kingdom_id => $kingdom1->id );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id,
        established => DateTime->now->subtract( days => 3 ), );

    $garrison->claim_land;

    $garrison->claim_land_order(1);
    $garrison->update;

    # WHEN
    $party->change_allegiance($kingdom2);
    $party->update;
    $self->{action}->run();

    # THEN
    foreach my $land (@land) {
        $land->discard_changes;
        is( $land->kingdom_id, $kingdom2->id, "Land now claimed by new kingdom" );
        is( $land->claimed_by_id, $garrison->id, "Garrison claimed sector " . $land->id );
        is( $land->claimed_by_type, 'garrison', "Claimed by type correct for sector " . $land->id );
    }
}

1;
