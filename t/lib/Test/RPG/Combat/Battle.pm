use strict;
use warnings;

package Test::RPG::Combat::Battle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Item;

use Data::Dumper;

use RPG::Combat::Battle;

sub test_get_combatant_list_no_history_multiple_combatants : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    
    my @combatants = ($party->characters, $cg->creatures);
    
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {}};
    $battle->mock('session', sub { return $session });
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, @combatants);
    
    # THEN
    is(scalar @sorted_combatants, scalar @combatants, "No one has extra attacks");
}

sub test_get_combatant_list_attack_history_updated : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::MockObject->new();
    $character->set_always('number_of_attacks', 2);
    $character->set_true('is_character');
    $character->set_always('id', 1);
    
    my $creature = Test::MockObject->new();
    $creature->set_always('number_of_attacks', 1);
    $creature->set_false('is_character');
    $creature->set_always('id', 1);
    
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {}};
    $battle->mock('session', sub { return $session });
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character, $creature);
    
    # THEN
    is($session->{attack_history}{character}{1}[0], 2, "Session updated for character");
    is($session->{attack_history}{creature}{1}[0], 1, "Session updated for creature");
}

sub test_get_combatant_list_with_history : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::MockObject->new();
    $character->set_always('number_of_attacks', 2);
    $character->set_true('is_character');
    $character->set_always('id', 1);
        
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {'character' => { '1' => [2,2] }}};
    $battle->mock('session', sub { return $session });
   
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character);
    
    # THEN
    is(scalar @sorted_combatants, 2, "Character added twice");

    my ($name, $args) = $character->next_call(4);
    is($name, 'number_of_attacks', "Number of attacks called");
    is($args->[1], 2, "First attack history passed");
    is($args->[2], 2, "Second attack history passed");
    is($session->{attack_history}{character}{1}[2], 2, "Session updated for character");
}

sub test_check_character_attack : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',1);

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value  => 1,
            }
        ]
    );
    
    is($item->variable('Durability'), 1, "Created item's durability set");
    
    my $character_weapons = {};
    $character_weapons->{1}{id} = $item->id;
    $character_weapons->{1}{durability} = 1;
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});
    
    $self->mock_dice;
    $self->{roll_result} = 1;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is_deeply($ret, {weapon_broken => 1}, "Weapon broken message returned");
    
    $item->discard_changes;
    is($item->variable('Durability'), 0, "Item's durability updated");    
        
}

sub test_check_character_attack_with_ammo : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',2);

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => 2,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 5,
            
            },
        ]
    );
        
    my $character_weapons = {};        
    $character_weapons->{2}{id} = 1;
    $character_weapons->{2}{durability} = 1;
    $character_weapons->{2}{ammunition} = [
        {
            id => $ammo1->id,
            quantity => 5,
        },
        # Non-existant ammo should not be read (will die if it is)
        {
            id => 55,
            quantity => 99,
        }
    ];
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});    
    
    $self->mock_dice;
    $self->{roll_result} = 2;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is($ret, undef, "No messages returned");
    
    $ammo1->discard_changes;
    is($ammo1->variable('Quantity'), 4, "Quantity of ammo updated");
}

sub test_check_character_attack_with_ammo_run_out : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',2);

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => 2,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 0,
            
            },
        ]
    );
            
    my $character_weapons = {};              
    $character_weapons->{2}{id} = 1;
    $character_weapons->{2}{durability} = 1;
    $character_weapons->{2}{ammunition} = [
        {
            id => $ammo1->id,
            quantity => 0,
        },
    ];
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});    
    
    $self->mock_dice;    
    $self->{roll_result} = 2;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is_deeply($ret, { no_ammo => 1 }, "No messages returned");
    
    $ammo1->discard_changes;
    is($ammo1->in_storage, 0, "Quantity of ammo updated");    
        
}

1;