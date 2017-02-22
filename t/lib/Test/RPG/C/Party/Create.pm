use strict;
use warnings;

package Test::RPG::C::Party::Create;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Player;

use RPG::C::Party::Create;

sub test_save_party : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 5, class => 'Warrior' );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 20 );

    $self->{session}{player} = $party->player;
    $self->{stash}{party}    = $party;
    $self->{params}{name}    = 'new party';

    $self->{config}{starting_turns}          = 500;
    $self->{config}{start_gold}              = 500;
    $self->{config}{min_starting_prosperity} = 10;
    $self->{config}{max_starting_prosperity} = 30;

    # WHEN
    RPG::C::Party::Create->save_party( $self->{c} );

    # THEN
    $party->discard_changes;
    is( $party->name,    'new party',    "Party name saved" );
    is( $party->turns,   500,            "Party start turns set" );
    is( $party->gold,    500,            "Party start gold set" );
    is( $party->land_id, $town->land_id, "Party put in town" );
}

sub test_save_party_with_promo_code : Tests(5) {
    my $self = shift;

    # GIVEN
    my $promo_org = $self->{schema}->resultset('Promo_Org')->create( { name => 'promo', extra_start_turns => 100 } );
    my $promo_code = $self->{schema}->resultset('Promo_Code')->create( { promo_org_id => $promo_org->id, code => 1234, uses_remaining => 4 } );
    my $player = Test::RPG::Builder::Player->build_player( $self->{schema}, promo_code_id => $promo_code->id );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player->id, character_count => 5, class => 'Warrior' );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 20 );

    $self->{session}{player} = $player;
    $self->{stash}{party}    = $party;
    $self->{params}{name}    = 'new party';

    $self->{config}{starting_turns}          = 500;
    $self->{config}{start_gold}              = 500;
    $self->{config}{min_starting_prosperity} = 10;
    $self->{config}{max_starting_prosperity} = 30;

    # WHEN
    RPG::C::Party::Create->save_party( $self->{c} );

    # THEN
    $party->discard_changes;
    is( $party->name, 'new party', "Party name saved" );
    is( $party->turns, 600, "Party start turns set, with extra promo code turns" );
    is( $party->gold,    500,            "Party start gold set" );
    is( $party->land_id, $town->land_id, "Party put in town" );

    $promo_code->discard_changes;
    is( $promo_code->uses_remaining, 3, "Promo code uses remaining reduced" );
}
