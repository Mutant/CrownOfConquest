use strict;
use warnings;

package Test::RPG::Schema::Building_Upgrade;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureGroup;

sub upgrade_setup : Tests(setup) {
    my $self = shift;

    $self->{schema}->resultset('Building_Upgrade_Type')->search()->update( { modifier_per_level => 3 } );
}

sub test_bonuses_applied_to_wilderness_garrison_when_upgrade_created : Tests(1) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, character_count => 0 );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10, garrison_id => $garrison->id );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $party->id, owner_type => 'party', land_id => $land[4]->id, );

    # WHEN
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Defence',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level   => 1,
        }
    );

    # THEN
    $character->discard_changes;
    is( $character->defence_factor, 17, "DF bonus applied to character when upgrade created" );
}

sub test_bonuses_applied_to_wilderness_garrison_when_upgrade_level_increased : Tests(2) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, character_count => 0 );
    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, garrison_id => $garrison->id );
    my $character2 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 12, garrison_id => $garrison->id );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $party->id, owner_type => 'party', land_id => $land[4]->id, );

    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Attack',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level   => 1,
        }
    );

    # WHEN
    my ($upgrade) = $building->upgrades;
    $upgrade->level( $upgrade->level + 1 );
    $upgrade->update;

    # THEN
    $character1->discard_changes;
    is( $character1->attack_factor, 16, "AF bonus applied to first character when upgrade level increased" );

    $character2->discard_changes;
    is( $character2->attack_factor, 18, "AF bonus applied to second character when upgrade level increased" );
}

sub test_bonuses_applied_to_town_garrison_when_upgrade_created : Tests(2) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $town->id, owner_type => 'town', land_id => $land[0]->id );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, creature_group_id => $cg->id );
    my $garrison_char = Test::RPG::Builder::Character->build_character( $self->{schema}, creature_group_id => $cg->id,
        status => 'mayor_garrison', status_context => $town->id );

    # WHEN
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Protection',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level   => 1,
        }
    );

    # THEN
    $mayor->discard_changes;
    is( $mayor->resistance('Ice'), 3, "Resistance bonus applied correctly to mayor when upgrade created" );

    $garrison_char->discard_changes;
    is( $garrison_char->resistance('Fire'), 3, "Resistance bonus applied correctly to garrison_char when upgrade created" );
}

sub test_bonuses_applied_to_town_garrison_when_upgrade_level_increased : Tests(2) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $town->id, owner_type => 'town', land_id => $land[0]->id );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, creature_group_id => $cg->id );
    my $garrison_char = Test::RPG::Builder::Character->build_character( $self->{schema}, creature_group_id => $cg->id,
        status => 'mayor_garrison', status_context => $town->id );

    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Protection',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level   => 1,
        }
    );

    # WHEN
    my ($upgrade) = $building->upgrades;
    $upgrade->level( $upgrade->level + 1 );
    $upgrade->update;

    # THEN
    $mayor->discard_changes;
    is( $mayor->resistance('Ice'), 6, "Resistance bonus applied correctly to mayor when upgrade level increased" );

    $garrison_char->discard_changes;
    is( $garrison_char->resistance('Fire'), 6, "Resistance bonus applied correctly to garrison_char when upgrade level increased" );
}

sub test_cant_take_level_to_negative_with_temp_damage : Tests(1) {
    my $self = shift;

    # GIVEN
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema},
        upgrades => {
            'Rune of Defence' => 2,
        },
    );
    my ($upgrade) = $building->upgrades;

    # WHEN
    $upgrade->damage(4);

    # THEN
    is( $upgrade->effective_level, 0, "Effective level does not go below 0" );

}

1;
