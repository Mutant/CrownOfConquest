use strict;
use warnings;

package Test::RPG::Builder::Combat_Log;

use Test::RPG::Builder::Party;

use DateTime;

sub build_log {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    unless ( $params{opp_2} ) {
        my $party = Test::RPG::Builder::Party->build_party( $schema, character_count => 2 );
        $params{opp_2} = $party;
    }

    my $log = $schema->resultset('Combat_Log')->create(
        {
            opponent_1_id     => $params{opp_1}->id,
            opponent_1_type   => $params{opp_1}->group_type,
            opponent_2_id     => $params{opp_2}->id,
            opponent_2_type   => $params{opp_2}->group_type,
            encounter_started => $params{encounter_started} || DateTime->now(),
            encounter_ended   => $params{encounter_ended} || DateTime->now(),
        }
    );

    return $log;
}

1;
