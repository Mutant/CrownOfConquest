use strict;
use warnings;

package Test::RPG::Combat::CreatureBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;

sub startup : Tests(startup => 1) {
    use_ok 'RPG::Combat::CreatureBattle';
}

sub test_process_effects_one_char_effect : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->party_id( $party->id );
    $character->update;

    my $effect = $self->{schema}->resultset('Effect')->create(
        {
            effect_name => 'Foo',
            time_left   => 2,
            combat      => 1,
        },
    );

    $self->{schema}->resultset('Character_Effect')->create(
        {
            character_id => $character->id,
            effect_id    => $effect->id,
        }
    );

    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

    my $battle = RPG::Combat::CreatureBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
    );

    # WHEN
    $battle->process_effects;
    
    # THEN
    my @effects = $character->character_effects;
    is(scalar @effects, 1, "Character still has one effect");
    is($effects[0]->effect->time_left, 1, "Time left has been reduced");
}

sub test_character_action_no_target : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->party_id( $party->id );
    $character->last_combat_action( 'Attack' );
    $character->update;
           
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    
    my $battle = RPG::Combat::CreatureBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
    );
    
    # WHEN
    my $results = $battle->character_action($character);
    
    isa_ok($results->[0], "RPG::Schema::Creature", "opponent was a creature");
    is($results->[0]->creature_group_id, $cg->id, ".. from the correct cg");
    ok($results->[1] > 0, "Damage greater than 0"); 
}

1;
