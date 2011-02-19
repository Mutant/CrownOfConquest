use strict;
use warnings;

package Test::RPG::C::Town::Recruitment_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;
use Test::Exception;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Day;

use RPG::C::Town::Recruitment;

sub test_sell_invalid_character : Tests(1) {
    my $self = shift;

    my $other_party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $other_party->id );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );

    $self->{params}{character_id} = $character->id;
    $self->{stash}{party}         = $party;

    throws_ok( sub { RPG::C::Town::Recruitment->sell( $self->{c} ); }, qr/Invalid character id:/, "Can't sell a character from another party" );
}

sub test_sell : Tests(5) {
    my $self = shift;

    my $party     = Test::RPG::Builder::Party->build_party( $self->{schema} );
    
    my @characters;
    for my $count (1 .. 5) {
        push @characters, Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, party_order => $count );
    }
    
    my $character_to_sell = $characters[2];
    
    my $town      = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $day       = Test::RPG::Builder::Day->build_day( $self->{schema} );

    $self->{params}{character_id}  = $character_to_sell->id;
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $town->location;
    $self->{stash}{today}          = $day;
    $self->{config}{url_root}      = '';

    RPG::C::Town::Recruitment->sell( $self->{c} );

    $character_to_sell->discard_changes;
    is( $character_to_sell->party_id,    undef,     "Character no longer in a party" );
    is( $character_to_sell->town_id,     $town->id, "Character now belongs to town he was sold in" );
    is( $character_to_sell->party_order, undef,     "Character's party order cleared" );
    
    my @updated_characters = $party->characters;
    is( scalar @updated_characters, 4, "4 chars left in the party");
    
    my @order_seen;
    foreach my $updated_char (@updated_characters) {
        push @order_seen, $updated_char->party_order;
    }
    
    is_deeply([sort { $a <=> $b } @order_seen], [1 .. scalar @updated_characters], "Party order is still contiguous");
    
}

1;
