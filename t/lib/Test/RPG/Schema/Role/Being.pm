use strict;
use warnings;

package Test::RPG::Schema::Building_Type;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;

sub startup : Tests(startup) {
    my $self = shift;
    
    $self->mock_dice;   
}

sub shutdown : Tests(shutdown) {
    my $self = shift;
    
    $self->unmock_dice;   
}

sub test_hit_with_resistance_char_didnt_resist : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->resist_fire(3);
    $character->update;
    
    $self->{roll_result} = 10;
    
    # WHEN
    my $res = $character->hit_with_resistance('Fire', 3);
    
    # THEN
    is($res, 0, "Char didn't resist");
    
    $character->discard_changes;
    is($character->hit_points, 7, "Character took damage");
       
}

sub test_hit_with_resistance_char_resisted : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->resist_fire(11);
    $character->update;
    
    $self->{roll_result} = 10;
    
    # WHEN
    my $res = $character->hit_with_resistance('Fire', 3);
    
    # THEN
    is($res, 1, "Char resisted");
    
    $character->discard_changes;
    is($character->hit_points, 10, "Character didn't take damage");
       
}
    
1;