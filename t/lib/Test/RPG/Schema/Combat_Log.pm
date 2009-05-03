use strict;
use warnings;

package Test::RPG::Schema::Combat_Log;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;

sub test_party_relationships : Tests {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $cg    = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

    my $combat_log = $self->{schema}->resultset('Combat_Log')->create(
        {
            opponent_1_id   => $party->id,
            opponent_1_type => 'party',
            opponent_2_id   => $cg->id,
            opponent_2_type => 'creature_group',
        },
    );

    # WHEN
    my $read_log = $self->{schema}->resultset('Combat_Log')->find(
        {
            combat_log_id => $combat_log->id,
        },
    );
    my $opp1 = $read_log->opponent_1;
    my $opp2 = $read_log->opponent_2;

    # THEN
    isa_ok( $opp1, 'RPG::Schema::Party', "Party object reutrned as opponent 1" );
    is( $opp1->id, $party->id, "Correct party related" );
    isa_ok( $opp2, 'RPG::Schema::CreatureGroup', "CG object reutrned as opponent 1" );
    is( $opp2->id, $cg->id, "Correct cg related" );

}

1;
