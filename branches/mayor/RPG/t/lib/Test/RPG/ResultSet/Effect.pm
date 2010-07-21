package Test::RPG::ResultSet::Effect;

use strict;
use warnings;

use base qw(Test::RPG::DB);

use Test::More;
use Test::RPG::Builder::Character;

__PACKAGE__->runtests() unless caller();

sub startup : Tests(startup=>1) {
    my $self = shift;
    
    use_ok 'RPG::ResultSet::Effect';
     
}

sub test_create_character_effect : Tests(7) {
	my $self = shift;
	
	# GIVEN
	my $character = Test::RPG::Builder::Character->build_character($self->{schema});
	
	# WHEN
	$self->{schema}->resultset('Effect')->create_effect(
		{
			effect_name => 'Test',
			target => $character,
			duration => 3,
			modifier => 4,
			combat => 1,
			modified_state => 'state',
		}
	);
	
	# THEN
	my @effect = $character->character_effects;
	
	is(scalar @effect, 1, "One effect found on character");
	my $effect = $effect[0]->effect;
	is($effect->effect_name, 'Test', "Effect name set correctly");
	is($effect->time_left, 3, "Effect time set correctly");
	is($effect->modifier, '4.00', "Effect modifier set correctly");
	is($effect->modified_stat, 'state', "Effect stat set correctly");
	is($effect->combat, 1, "Effect combat flag set correctly");
	is($effect->time_type, 'round', "Effect time type set correctly");
		
}

1;