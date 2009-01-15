use strict;
use warnings;

package Test::RPG::C::Town_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;

sub test_town_hall : Tests(no_plan) {
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

1;
