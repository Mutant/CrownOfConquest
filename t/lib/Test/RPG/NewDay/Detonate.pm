use strict;
use warnings;

package Test::RPG::NewDay::Detonate;

use base qw(Test::RPG::NewDay::ActionBase);
__PACKAGE__->runtests unless caller();

use Test::More;
use DateTime;

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;

sub test_startup : Tests(startup) {
    my $self = shift;

    $self->mock_dice;
}

sub test_shutdown : Tests(shutdown) {
    my $self = shift;

    $self->unmock_dice;
}

sub setup : Test(setup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Detonate';

    $self->setup_context;

    $self->{action} = RPG::NewDay::Action::Detonate->new( context => $self->{mock_context} );
}

sub test_detonate_single_bomb_wilderness_building : Tests(7) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, x_size => 3, 'y_size' => 3 );
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $bomb = $self->{schema}->resultset('Bomb')->create(
        {
            land_id  => $land[4]->id,
            level    => 20,
            planted  => DateTime->now->subtract( minutes => 6 ),
            party_id => $party1->id,
        }
    );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema},
        upgrades => {
            'Rune Of Protection' => 2,
            'Rune Of Attack'     => 1,
        },
        land_id    => $land[1]->id,
        owner_id   => $party2->id,
        owner_type => 'party',
    );

    $self->{rolls} = [ 2, 100, 10, 10, 1 ];

    # WHEN
    $self->{action}->run();

    # THEN
    $bomb->discard_changes;
    isnt( $bomb->detonated, undef, "Bomb was detonated" );

    my @messages = $party1->messages;
    is( scalar @messages, 1, "Message created for detonating party" );
    is( $messages[0]->message, "A bomb that we planted has detonated. 2 upgrades were damaged", "Correct message text" );

    @messages = $party2->messages;
    is( scalar @messages, 1, "Message created for building owner" );
    like( $messages[0]->message, qr{^The Tower at 1, 2 suffered damage to its upgrades as the result of a magical bomb.}, "Correct message text" );
    like( $messages[0]->message, qr{The Rune of Attack upgrade lost 1 level (?:temporarily|permanently).}, "Correct message text" );
    like( $messages[0]->message, qr{The Rune of Protection upgrade lost 1 level (?:temporarily|permanently).}, "Correct message text" );
}

sub test_detonate_multiple_bombs_town_building : Tests(6) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, x_size => 3, 'y_size' => 3 );
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $land[0]->id );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
        $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 5, y => 5 },
        make_stairs  => 1,
    );
    my @sectors = $dungeon_room->sectors;

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $bomb1 = $self->{schema}->resultset('Bomb')->create(
        {
            dungeon_grid_id => $sectors[4]->id,
            level           => 20,
            planted         => DateTime->now->subtract( minutes => 6 ),
            party_id        => $party1->id,
        }
    );

    my $bomb2 = $self->{schema}->resultset('Bomb')->create(
        {
            dungeon_grid_id => $sectors[5]->id,
            level           => 20,
            planted         => DateTime->now->subtract( minutes => 6 ),
            party_id        => $party1->id,
        }
    );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my ($char) = $party2->characters;
    $char->mayor_of( $town->id );
    $char->update;
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema},
        upgrades => {
            'Rune Of Protection' => 6,
        },
        land_id    => $land[0]->id,
        owner_id   => $town->id,
        owner_type => 'town',
    );

    $self->{rolls} = [ 2, 2, 2, 10, 2, 1 ];

    # WHEN
    $self->{action}->run();

    # THEN
    $bomb1->discard_changes;
    isnt( $bomb1->detonated, undef, "Bomb 1 was detonated" );

    $bomb2->discard_changes;
    isnt( $bomb2->detonated, undef, "Bomb 2 was detonated" );

    my @messages = $party1->messages;
    is( scalar @messages, 1, "Message created for detonating party" );
    is( $messages[0]->message, "2 bombs that we planted have detonated. 2 upgrades were damaged", "Correct message text" );

    @messages = $party2->messages;
    is( scalar @messages, 1, "Message created for building owner" );
    is( $messages[0]->message, 'The Tower in the town of Test Town suffered damage to its upgrades as the result of a magical bomb. The Rune of Protection upgrade lost 1 level permanently, and 3 levels temporarily.',
        "Correct message text" );
}

1;
