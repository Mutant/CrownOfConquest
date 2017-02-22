use strict;
use warnings;

package Test::RPG::Schema::Skill::Metallurgy;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;

sub startup : Tests(startup) {
    my $self = shift;

    $self->mock_dice;

    $self->{skill} = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Metallurgy',
        }
    );
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    $self->unmock_dice;
}

sub test_execute : Tests(5) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my ($char) = $party->characters;

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $self->{skill}->id,
            character_id => $char->id,
            level        => 1,
        }
    );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema},
        item_type_name => 'Broken Item 1',
        variables      => {
            item_variable_name  => 'Durability',
            item_variable_value => 5,
            max_value           => 10,
        },
        character_id   => $char->id,
        equip_place_id => 1,
    );

    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema},
        item_type_name => 'Broken Item 2',
        variables      => {
            item_variable_name  => 'Durability',
            item_variable_value => 5,
            max_value           => 10,
        },
        character_id   => $char->id,
        equip_place_id => 2,
    );

    my $item3 = Test::RPG::Builder::Item->build_item( $self->{schema},
        item_type_name => 'Good Item 1',
        variables      => {
            item_variable_name  => 'Durability',
            item_variable_value => 10,
            max_value           => 10,
        },
        character_id   => $char->id,
        equip_place_id => 3,
    );

    my $item4 = Test::RPG::Builder::Item->build_item( $self->{schema},
        item_type_name => 'Non-durability Item 1',
        character_id   => $char->id,
        equip_place_id => 4,
    );

    $self->{rolls} = [ 1, 1, 1, 1 ];

    # WHEN
    $char_skill->execute('new_day');

    # THEN
    is( $party->day_logs->count, 1, "Party day logs updated" );
    my ($log) = $party->day_logs;

    is( $log->log, 'test used his Metallurgy skills, and made minor repairs to his Broken Item 1, and Broken Item 2.', "Log message is correct" );

    $item1->discard_changes;
    is( $item1->variable('Durability'), 8, "Item1 repaired" );

    $item2->discard_changes;
    is( $item2->variable('Durability'), 8, "Item2 repaired" );

    $item3->discard_changes;
    is( $item3->variable('Durability'), 10, "Item3 not repaired" );
}

1;
