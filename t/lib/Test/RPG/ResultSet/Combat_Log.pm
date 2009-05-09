package Test::RPG::ResultSet::Combat_Log;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;

use DateTime;

sub test_get_offline_log_count : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );

    my $now = DateTime->now();

    $party->last_action( $now->clone->subtract( hours => 5 ) );
    $party->update;

    my %combat_log_params = (
        opponent_1_id     => $party->id,
        opponent_1_type   => 'party',
        opponent_2_id     => 0,
        opponent_2_type   => 'creature_group',
        land_id           => 1,
        encounter_started => $now,

    );

    my $combat_log1 = $self->{schema}->resultset('Combat_Log')->create(
        {
            encounter_ended => $now->clone->subtract( hours => 5 ),
            %combat_log_params,
        },
    );
    
    my $combat_log2 = $self->{schema}->resultset('Combat_Log')->create(
        {
            encounter_ended => $now->clone->subtract( hours => 4 ),
            %combat_log_params,
        },
    );    

    my $combat_log3 = $self->{schema}->resultset('Combat_Log')->create(
        {
            encounter_ended   => $now->clone->subtract( hours => 3 ),
            opponent_2_id     => $party->id,
            opponent_2_type   => 'party',
            opponent_1_id     => 0,
            opponent_1_type   => 'creature_group',
            land_id           => 1,
            encounter_started => $now,
        },
    );
    
    my $combat_log4 = $self->{schema}->resultset('Combat_Log')->create(
        {
            encounter_ended   => $now->clone->subtract( hours => 3 ),
            opponent_2_id     => 77,
            opponent_2_type   => 'party',
            opponent_1_id     => 0,
            opponent_1_type   => 'creature_group',
            land_id           => 1,
            encounter_started => $now,
        },
    );    

    my $combat_log5 = $self->{schema}->resultset('Combat_Log')->create(
        {
            encounter_ended => $now->clone->subtract( hours => 6 ),
            %combat_log_params,
        },
    );
    
    # WHEN
    my $offline_combat_count = $self->{schema}->resultset('Combat_Log')->get_offline_log_count($party);
    
    # THEN
    is($offline_combat_count, 2, "Correct count of combat logs returned");
}

1;
