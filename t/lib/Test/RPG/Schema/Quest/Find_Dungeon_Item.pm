use strict;
use warnings;

package Test::RPG::Schema::Quest::Find_Dungeon_Item;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use List::Util qw(shuffle);

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Quest::Find_Dungeon_Item;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;

use RPG::Schema::Quest::Find_Dungeon_Item;

sub test_set_quest_params : Tests(11) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};
    my @land   = Test::RPG::Builder::Land->build_land($schema);

    my $town = $schema->resultset('Town')->create( { land_id => $land[4]->id, } );
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $schema, land_id => $land[8]->id, level => 2 );

    $self->{config}{quest_type_vars}{find_dungeon_item}{search_range}      = 3;
    $self->{config}{quest_type_vars}{find_dungeon_item}{gold_per_distance} = 45;
    $self->{config}{quest_type_vars}{find_dungeon_item}{xp_per_distance}   = 30;
    $self->{config}{data_file_path}              = 'data/';
    $self->{config}{dungeon_entrance_level_step} = 5;

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'find_dungeon_item' } );

    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
        $schema,
        dungeon_id   => $dungeon->id,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 5, y => 5 },
    );

    my $chest_sector = ( shuffle $dungeon_room->sectors )[0];

    my $chest = Test::RPG::Builder::Treasure_Chest->build_chest( $schema, dungeon_grid_id => $chest_sector->id );

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $schema, item_type => 'Artifact' );

    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            town_id       => $town->id,
            quest_type_id => $quest_type->id,
        }
    );

    # THEN
    is( $quest->quest_type_id, $quest_type->id, "Quest type id set correctly" );
    is( $quest->param_start_value('Dungeon'), $dungeon->id, "Dungeon param set correctly" );
    is( $quest->param_start_value('Item Found'), 0, "Item found param set correctly" );
    is( $quest->gold_value,       90, "Gold value set correctly" );
    is( $quest->xp_value,         60, "XP value set correctly" );
    is( $quest->min_level,        5,  "Min level set correctly" );
    is( $quest->days_to_complete, 20, "Days to complete set correctly" );

    is( defined $quest->param_start_value('Item'), 1, "Item param set" );

    my $item = $quest->item;
    is( $item->name,         "FooBar",       "Item named correctly" );
    is( $item->item_type_id, $item_type->id, "Item type set correctly" );
    is( $item->treasure_chest_id, $chest->id, "Item in correct treasure chest" );

}

sub test_check_action_item_not_found : Tests(1) {
    my $self = shift;

    # GIVEN
    my $quest  = Test::MockObject->new();
    my %params = (
        'Dungeon' => 1,
        'Item'    => 5,
    );
    $quest->mock( 'param_start_value', sub { return $params{ $_[1] } } );

    my $item1 = Test::MockObject->new();
    $item1->set_always( 'id', 1 );
    my $item2 = Test::MockObject->new();
    $item2->set_always( 'id', 2 );

    # WHEN
    my $result = RPG::Schema::Quest::Find_Dungeon_Item::check_action( $quest, undef, 'chest_opened', 1, [ $item1, $item2 ] );

    # THEN
    is( $result, 0, "Item not found in chest" );

}

sub test_check_action_item_found : Tests(3) {
    my $self = shift;

    # GIVEN
    my $quest  = Test::MockObject->new();
    my %params = (
        'Dungeon' => 1,
        'Item'    => 2,
    );
    $quest->mock( 'param_start_value', sub { return $params{ $_[1] } } );

    my $item1 = Test::MockObject->new();
    $item1->set_always( 'id', 1 );
    my $item2 = Test::MockObject->new();
    $item2->set_always( 'id', 2 );

    my $current_value = 0;
    my $param_record  = Test::MockObject->new();
    $param_record->mock( 'current_value', sub { $current_value = $_[1] } );
    $param_record->set_always('update');

    $quest->mock( 'param_record', sub { $_[1] eq 'Item Found' ? $param_record : undef } );

    # WHEN
    my $result = RPG::Schema::Quest::Find_Dungeon_Item::check_action( $quest, undef, 'chest_opened', 1, [ $item1, $item2 ] );

    # THEN
    is( $result,        1, "Item found in chest" );
    is( $current_value, 1, "Value of 'Item Found' param set to true" );
    $param_record->called_ok( 'update', "Update called on param record" );
}

sub test_check_quest_terminated_when_item_deleted : Tests(4) {
    my $self = shift;

    # GIVEN
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    $quest->party_id( $party->id );
    $quest->status('In Progress');
    $quest->update;

    my $item = $quest->item;

    # WHEN
    $item->delete;

    # THEN
    $quest->discard_changes;
    is( $quest->status, 'Terminated', "Quest terminated" );

    my $party_town = $self->{schema}->resultset('Party_Town')->find_or_create(
        {
            town_id  => $quest->town_id,
            party_id => $party->id,
        },
    );
    is( $party_town->prestige, -3, "Prestige lowered with town" );

    my @messages = $self->{schema}->resultset('Party_Messages')->search(
        {
            party_id => $party->id,
        }
    );

    is( scalar @messages, 1, "One party message created" );
    like( $messages[0]->message, qr{You've lost the item needed to complete the quest}m, "Correct message text" );
}

sub test_check_quest_ready_to_complete_when_item_is_on_party : Tests(1) {
    my $self = shift;

    # GIVEN
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    $quest->party_id( $party->id );
    $quest->status('In Progress');
    $quest->update;

    my $quest_param = $quest->param_record('Item Found');
    $quest_param->current_value(1);
    $quest_param->update;

    my ($character) = $party->characters;
    my $item = $quest->item;
    $item->character_id( $character->id );
    $item->update;

    # WHEN
    my $result = $quest->ready_to_complete;

    # THEN
    is( $result, 1, "Quest is ready to complete" );
}

sub test_check_quest_not_ready_to_complete_when_item_is_on_character_outside_of_party : Tests(1) {
    my $self = shift;

    # GIVEN
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id );
    $quest->party_id( $party->id );
    $quest->status('In Progress');
    $quest->update;

    my $quest_param = $quest->param_record('Item Found');
    $quest_param->current_value(1);
    $quest_param->update;

    my ($character) = $party->characters;
    $character->garrison_id( $garrison->id );
    $character->update;

    my $item = $quest->item;
    $item->character_id( $character->id );
    $item->update;

    # WHEN
    my $result = $quest->ready_to_complete;

    # THEN
    is( $result, 0, "Quest is not ready to complete" );
}

sub test_check_quest_not_ready_to_complete_when_item_is_on_character_in_the_inn : Tests(1) {
    my $self = shift;

    # GIVEN
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $quest->party_id( $party->id );
    $quest->status('In Progress');
    $quest->update;

    my $quest_param = $quest->param_record('Item Found');
    $quest_param->current_value(1);
    $quest_param->update;

    $character->status('inn');
    $character->status_context(1);
    $character->update;

    my $item = $quest->item;
    $item->character_id( $character->id );
    $item->update;

    # WHEN
    my $result = $quest->ready_to_complete;

    # THEN
    is( $result, 0, "Quest is not ready to complete" );
}

1;
