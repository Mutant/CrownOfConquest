use strict;
use warnings;

package Test::RPG::C::Combat_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;

use RPG::C::Combat;

use Data::Dumper;

sub test_process_effects_refreshes_stash : Tests(no_plan) {
    my $self = shift;
    
    my $creature_group = $self->{schema}->resultset('CreatureGroup')->create({         
    });
    
    my $creature_type = $self->{schema}->resultset('CreatureType')->create({
    });
    
    my $creature = $self->{schema}->resultset('Creature')->create({
        creature_group_id => $creature_group->id,
        creature_type_id => $creature_type->id,
	});
	
	my $party = Test::RPG::Builder::Party->build_party(
	   $self->{schema},
	);
	
	my $character = Test::RPG::Builder::Character->build_character(
	   $self->{schema},
	   party_id => $party->id,
	);
	
	my $effect1 = $self->{schema}->resultset('Effect')->create({
	    combat => 1,
	    time_left => 2,
	});

	my $effect2 = $self->{schema}->resultset('Effect')->create({
	    combat => 1,
	    time_left => 1,
	});
	
	my $creature_effect = $self->{schema}->resultset('Creature_Effect')->create({
	    creature_id => $creature->id,
	    effect_id => $effect1->id,
	});
	
	my $character_effect = $self->{schema}->resultset('Character_Effect')->create({
	    character_id => $character->id,
	    effect_id => $effect2->id,
	});
	
	$self->{stash} = {
	    creature_group => $self->{schema}->resultset('CreatureGroup')->get_by_id($creature_group->id),   
	    party => $self->{schema}->resultset('Party')->get_by_player_id($party->player_id),
	};
	
	$self->{session} = {
	    player => $party->owned_by_player,
	};
	
	RPG::C::Combat->process_effects($self->{c});
	
	my @creatures = $self->{stash}->{creature_group}->creatures;
	my @effects = $creatures[0]->creature_effects;	
	
	is($effects[0]->effect->time_left, 1, "Time left on effect decreased to 1 on creature's effect");
	
	my @characters = $self->{stash}->{party}->characters;
	@effects = $characters[0]->character_effects;
	
	is(scalar @effects, 0, "No effects on character, as it has been deleted");
}

1;