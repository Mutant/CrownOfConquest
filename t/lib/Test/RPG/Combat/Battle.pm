use strict;
use warnings;

package Test::RPG::Combat::Battle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;

use RPG::Combat::Battle;

sub test_get_combatant_list_no_history : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    
    my @combatants = ($party->characters, $cg->creatures);
    
    my $battle = Test::MockObject->new();
    $battle->set_always('attack_history', {});
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, @combatants);
    
    # THEN
    is(scalar @sorted_combatants, scalar @combatants, "No one has extra attacks");
}

sub test_get_combatant_list_with_history : Tests(4) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::MockObject->new();
    $character->set_always('number_of_attacks', 2);
    $character->set_true('is_character');
    $character->set_always('id', 1);
        
    my $battle = Test::MockObject->new();
    $battle->set_always('attack_history', {
        'character' => { '1' => [2,2] },
    });
    
   
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character);
    
    # THEN
    is(scalar @sorted_combatants, 2, "Character added twice");

    my ($name, $args) = $character->next_call(4);
    is($name, 'number_of_attacks', "Number of attacks called");
    is($args->[1], 2, "First attack history passed");
    is($args->[2], 2, "First attack history passed");    
}

1;