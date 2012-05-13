use strict;
use warnings;

package Test::RPG::Schema::Skill::Fletching;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Item_Type;

sub startup : Tests(startup) {
    my $self = shift;
    
    $self->mock_dice;
    
    $self->{skill} = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Fletching',
        }
    );    
}

sub shutdown : Tests(shutdown) {
    my $self = shift;
    
    $self->unmock_dice;
}

sub test_execute_existing_ammo : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1);
    my ($char) = $party->characters;
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $char->id,
            level => 1,
        }
    );

    my $item1 = Test::RPG::Builder::Item->build_item($self->{schema},
        item_type_name => 'Arrows',
        variables => {
            item_variable_name => 'Quantity',
            item_variable_value => 5,
        },
        character_id => $char->id,
        no_equip_place => 1,
    );
    
    my $item2 = Test::RPG::Builder::Item->build_item($self->{schema},
        item_type_name => 'Long Bow',
        attributes => {
            item_attribute_name => 'Ammunition',
            item_attribute_value => $item1->item_type_id,
        },
        super_category_name => 'Weapon',
        category_name => 'Ranged Weapon',
        character_id => $char->id,
    );
    
 
    $self->{rolls} = [1,20];
    
    # WHEN
    $char_skill->execute('new_day');
    
    # THEN
    is($party->day_logs->count, 1, "Party day logs updated");
    my ($log) = $party->day_logs; 
    
    is($log->log, 'test used his Fletching skills to create 10 Arrows for his Long Bow.', "Message is correct");
    
    $item1->discard_changes;
    is($item1->variable('Quantity'), 15, "Ammo quantity increased");
}

sub test_execute_new_ammo_item : Tests(4) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1);
    my ($char) = $party->characters;
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $char->id,
            level => 1,
        }
    );

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type($self->{schema},
        item_type => 'Arrows',
        variables => [{
            name => 'Quantity',
            create_on_insert => 1,
        }],
        character_id => $char->id,
    );
    
    my $item2 = Test::RPG::Builder::Item->build_item($self->{schema},
        item_type_name => 'Long Bow',
        attributes => {
            item_attribute_name => 'Ammunition',
            item_attribute_value => $item_type->id,
        },
        super_category_name => 'Weapon',
        category_name => 'Ranged Weapon',
        character_id => $char->id,
    );
    
 
    $self->{rolls} = [1,20,20];
    
    # WHEN
    $char_skill->execute('new_day');
    
    # THEN
    is($party->day_logs->count, 1, "Party day logs updated");
    my ($log) = $party->day_logs; 
    
    is($log->log, 'test used his Fletching skills to create 10 Arrows for his Long Bow.', "Message is correct");
    
    my ($new_item) = grep { $_->id != $item2->id } $char->items;
    is($new_item->item_type_id, $item_type->id, "New item of ammunition type created");
    is($new_item->variable('Quantity'), 10, "New item has correct quantity");
}

sub test_execute_not_a_ranged_weapon : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1);
    my ($char) = $party->characters;
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $char->id,
            level => 1,
        }
    );

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type($self->{schema},
        item_type => 'Arrows',
        variables => [{
            name => 'Quantity',
            create_on_insert => 1,
        }],
        character_id => $char->id,
    );
    
    my $item2 = Test::RPG::Builder::Item->build_item($self->{schema},
        item_type_name => 'Long Bow',
        super_category_name => 'Weapon',
        category_name => 'Melee Weapon',
        character_id => $char->id,
    );
    
 
    $self->{rolls} = [1,20,20];
    
    # WHEN
    $char_skill->execute('new_day');
    
    # THEN
    is($party->day_logs->count, 0, "No party log created");
    
    is(grep({ $_->id != $item2->id } $char->items), 0, "No new items created");
}


1;