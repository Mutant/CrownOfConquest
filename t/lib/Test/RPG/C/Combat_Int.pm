use strict;
use warnings;

package Test::RPG::C::Combat_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;

sub combat_startup : Test(startup => 1) {
    my $self = shift;

    $self->{dice} = Test::MockObject->fake_module( 'Games::Dice::Advanced', roll => sub { $self->{roll_result} || 0 }, );

    use_ok('RPG::C::Combat');
}

sub test_process_effects_refreshes_stash : Tests(no_plan) {
    my $self = shift;

    my $creature_group = $self->{schema}->resultset('CreatureGroup')->create( {} );

    my $creature_type = $self->{schema}->resultset('CreatureType')->create( {} );

    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_group_id => $creature_group->id,
            creature_type_id  => $creature_type->id,
        }
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, );

    my $effect1 = $self->{schema}->resultset('Effect')->create(
        {
            combat    => 1,
            time_left => 2,
        }
    );

    my $effect2 = $self->{schema}->resultset('Effect')->create(
        {
            combat    => 1,
            time_left => 1,
        }
    );

    my $creature_effect = $self->{schema}->resultset('Creature_Effect')->create(
        {
            creature_id => $creature->id,
            effect_id   => $effect1->id,
        }
    );

    my $character_effect = $self->{schema}->resultset('Character_Effect')->create(
        {
            character_id => $character->id,
            effect_id    => $effect2->id,
        }
    );

    $self->{stash} = {
        creature_group => $self->{schema}->resultset('CreatureGroup')->get_by_id( $creature_group->id ),
        party          => $self->{schema}->resultset('Party')->get_by_player_id( $party->player_id ),
    };

    $self->{session} = { player => $party->player, };

    RPG::C::Combat->process_effects( $self->{c} );

    my @creatures = $self->{stash}->{creature_group}->creatures;
    my @effects   = $creatures[0]->creature_effects;

    is( $effects[0]->effect->time_left, 1, "Time left on effect decreased to 1 on creature's effect" );

    my @characters = $self->{stash}->{party}->characters;
    @effects = $characters[0]->character_effects;

    is( scalar @effects, 0, "No effects on character, as it has been deleted" );
}

sub test_calculate_factors : Tests(3) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item      = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
            }
        ],
        attributes => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 5,
            },
            {
                item_attribute_name  => 'Damage',
                item_attribute_value => 5,
            }
        ],
        super_category_name => 'Weapon',
    );
    $item->character_id( $character->id );
    $item->update;

    # WHEN
    RPG::C::Combat->calculate_factors( $self->{c}, [$character] );

    # THEN
    is( $self->{session}{character_weapons}{ $character->id }{id},         $item->id, "Item id saved in session" );
    is( $self->{session}{character_weapons}{ $character->id }{durability}, 5,         "Item durability saved in session" );
    is( $self->{session}{character_weapons}{ $character->id }{ammunition}, undef,     "No ammo" );

}

sub test_fight : Tests(5) {
    my $self = shift;

    # GIVEN
    my $result = { messages => 'messages from combat', };

    my $mock_battle = Test::MockObject->new();
    my %new_args;
    $mock_battle->fake_module(
        'RPG::Combat::CreatureWildernessBattle',
        new => sub {
            shift @_;
            %new_args = @_;
            return $mock_battle;
        },
    );
    $mock_battle->mock(
        'execute_round',
        sub {
            return $result;
        },
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Combat->fight( $self->{c} );

    # THEN
    is( $new_args{creature_group}->id, $cg->id,    "Creature group passed in correctly" );
    is( $new_args{party}->id,          $party->id, "Creature group passed in correctly" );
    is( $new_args{creatures_can_flee}, 1,          "Creatures allowed to flee" );
    $mock_battle->called_ok('execute_round');

    is( $template_args->[0][0]{params}{combat_messages}, "messages from combat", "Combat messages passed to template" );
}

sub test_flee_flee_successful : Tests(7) {
    my $self = shift;

    # GIVEN
    my $result = { party_fled => 1, };

    my $mock_battle = Test::MockObject->new();
    my %new_args;
    $mock_battle->fake_module(
        'RPG::Combat::CreatureWildernessBattle',
        new => sub {
            shift @_;
            %new_args = @_;
            return $mock_battle;
        },
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;
    
    my $orig_location = $party->land_id;

    $mock_battle->mock(
        'execute_round',
        sub {
            $party->land_id($party->land_id+1);
            $party->update;
            return $result;
        },
    );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Combat->flee( $self->{c} );

    # THEN
    is( $new_args{creature_group}->id, $cg->id,    "Creature group passed in correctly" );
    is( $new_args{party}->id,          $party->id, "Creature group passed in correctly" );
    is( $new_args{creatures_can_flee}, 1,          "Creatures allowed to flee" );
    is( $new_args{party_flee_attempt}, 1,          "Flee attempted");
    is( $self->{stash}{messages}, "You got away!", "Flee message set");
    is( $self->{stash}{party}->land_id, $orig_location+1, "Party record in stash refreshed");
    is( $self->{stash}{creature_group}, undef, "Creature group in stash cleared");
    
}

1;
