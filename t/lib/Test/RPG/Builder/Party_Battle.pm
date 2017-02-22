use strict;
use warnings;

package Test::RPG::Builder::Party_Battle;

sub build_battle {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $battle = $schema->resultset('Party_Battle')->create( {} );

    $battle->add_to_participants( { party_id => $params{party_1}->id, } );

    $battle->add_to_participants( { party_id => $params{party_2}->id, } );

    return $battle;
}

1;
