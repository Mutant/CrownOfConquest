use strict;
use warnings;

package Test::RPG::Schema::Spell::Farsight;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Data::Dumper;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Creature_Orb;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::CreatureGroup;

sub test_cast_on_empty_sector_everything_found : Tests(7) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Farsight', } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, land_id => $land[0]->id );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, level => 25, );

    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );

    $self->mock_dice;
    $self->{roll_result} = 3;

    # WHEN
    my $result = $spell->cast( $character, $land[8] );

    # THEN
    is( $result->type, 'farsight', "Correct result type" );
    is( $result->defender->id, $land[8]->id, "Correct 'defender' (i.e. sector)" );
    is( $result->custom->{garrison}, 'none', "No garrison found" );
    is( $result->custom->{dungeon},  'none', "No dungeon found" );
    is( $result->custom->{orb},      'none', "No orb found" );
    is( $result->custom->{building}, 'none', "No building found" );
    is( $result->custom->{building_upgrade}, 'none', "No building_upgrade found" );
}

sub test_cast_on_empty_sector_nothing_found : Tests(3) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Farsight', } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, land_id => $land[0]->id );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, level => 1, );

    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );

    $self->mock_dice;
    $self->{roll_result} = 3;

    # WHEN
    my $result = $spell->cast( $character, $land[8] );

    # THEN
    is( $result->type, 'farsight', "Correct result type" );
    is( $result->defender->id, $land[8]->id, "Correct 'defender' (i.e. sector)" );
    is_deeply( $result->custom, {}, "No discoveries made" );
}

sub test_cast_on_full_wilderness_sector : Tests(9) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Farsight', } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, land_id => $land[0]->id );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, level => 25, );

    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[8]->id,
        upgrades => {
            'Rune Of Defence'    => 5,
            'Rune Of Protection' => 2,
        },
    );

    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, land_id => $land[8]->id );

    my $orb = Test::RPG::Builder::Creature_Orb->build_orb( $self->{schema}, land_id => $land[8]->id );

    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, land_id => $land[8]->id );

    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );

    $self->mock_dice;
    $self->{roll_result} = 3;

    # WHEN
    my $result = $spell->cast( $character, $land[8] );

    # THEN
    is( $result->type, 'farsight', "Correct result type" );
    is( $result->defender->id, $land[8]->id, "Correct 'defender' (i.e. sector)" );
    is( $result->custom->{garrison}->id, $garrison->id, "Garrison found" );
    is( $result->custom->{dungeon}->id,  $dungeon->id,  "Dungeon found" );
    is( $result->custom->{orb}->id,      $orb->id,      "Orb found" );
    is( $result->custom->{building}, 'Tower', "Tower found in sector" );
    is( $result->custom->{building_upgrade}{'Rune of Defence'}, '5', "Rune of defence found" );
    is( $result->custom->{building_upgrade}{'Rune of Protection'}, '2', "Rune of protection found" );
    is( $result->custom->{building_upgrade}{'Rune of Attack'}, 'none', "No rune of attack found" );
}

sub test_cast_on_full_towm_sector : Tests(15) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Farsight', } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, land_id => $land[0]->id );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, level => 25, );

    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[8]->id,
        upgrades => {
            'Market'   => 3,
            'Barracks' => 1,
        },
    );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[8]->id, );

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );

    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, land_id => $land[8]->id, type => 'castle', rooms => 2 );
    my @rooms = $castle->rooms;
    my @sectors;
    foreach my $room (@rooms) {
        push @sectors, $room->sectors;
    }

    my $guard_type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, category_name => 'Guard', type => 'Lazy Guard', level => 2 );
    my $guard_type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, category_name => 'Guard', type => 'Foolish Guard', level => 3 );

    my $guard_group1 = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, type_id => $guard_type1->id, dungeon_grid_id => $sectors[0]->id );
    my $guard_group2 = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, type_id => $guard_type2->id, dungeon_grid_id => $sectors[1]->id, creature_count => 5 );

    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );

    $self->mock_dice;
    $self->{roll_result} = 3;

    # WHEN
    my $result = $spell->cast( $character, $land[8] );

    # THEN
    is( $result->type, 'farsight', "Correct result type" );
    is( $result->defender->id, $land[8]->id, "Correct 'defender' (i.e. sector)" );

    is( $result->custom->{town}->id,  $town->id,  "Town found" );
    is( $result->custom->{mayor}->id, $mayor->id, "Mayor found" );

    is( scalar @{ $result->custom->{town_guards} }, 2, "2 guard type records found" );
    is( $result->custom->{town_guards}[0]->get_column('type'), 'Lazy Guard', "Lazy guards first type returned" );
    is( $result->custom->{town_guards}[0]->get_column('count'), '3', "Correct count of Lazy guards" );
    is( $result->custom->{town_guards}[1]->get_column('type'), 'Foolish Guard', "Foolish guards second type returned" );
    is( $result->custom->{town_guards}[1]->get_column('count'), '5', "Correct count of Foolish guards" );

    is( $result->custom->{building}, 'Tower', "Tower found in sector" );
    is( $result->custom->{building_upgrade}{'Rune of Defence'}, 'none', "Rune of defence not found" );
    is( $result->custom->{building_upgrade}{'Rune of Protection'}, 'none', "Rune of protection not found" );
    is( $result->custom->{building_upgrade}{'Rune of Attack'}, 'none', "No rune of attack not found" );
    is( $result->custom->{building_upgrade}{'Market'}, '3', "Market found" );
    is( $result->custom->{building_upgrade}{'Barracks'}, '1', "Barracks found" );
}

1;
