use strict;
use warnings;

package Test::RPG::C::Town_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;

use Test::More;

use RPG::C::Town;

sub test_town_hall : Tests(0) {
    my $self = shift;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );

    my @characters;
    for my $count ( 1 .. 5 ) {
        push @characters, Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, party_order => $count );
    }

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );

    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $town->location;

}

sub test_enter : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema} );
    $town->land_id(5555);
    $town->prosperity(50);
    $town->update;

    $self->{stash}{party}           = $party;
    $self->{params}{land_id}        = $town->land_id;
    $self->{params}{payment_method} = 'gold';

    $self->{config} = {
        tax_per_prosperity => 0.5,
        tax_level_modifier => 0.5,
        tax_turn_divisor   => 10,
    };

    $self->{mock_forward}{'/map/move_to'} = sub { };

    # WHEN
    RPG::C::Town->enter( $self->{c} );

    # THEN
    my $party_town = $self->{schema}->resultset('Party_Town')->find(
        {
            party_id => $party->id,
            town_id  => $town->id,
        }
    );
    is( defined $party_town,                1,  "party town record created" );
    is( $party_town->tax_amount_paid_today, 12, "Gold amount recorded" );

}

1;
