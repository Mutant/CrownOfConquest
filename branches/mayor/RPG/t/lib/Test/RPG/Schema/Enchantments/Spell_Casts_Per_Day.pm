use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Spells_Cast_Per_Day;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;

sub test_startup : Tests(startup => 2) {
	my $self = shift;
	
	#use_ok('Games::Dice::Advanced');
	use_ok('RPG::Schema::Enchantments::Spell_Casts_Per_Day');
}

sub test_use : Tests(2) {
	my $self = shift;
	
	# GIVEN
    $self->mock_dice;
    $self->clear_dice_data;
    
    $self->{roll_result} = 6;	
	
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $target = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $target->hit_points(4);
    $target->update;
	
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'] );
	$item->variable_row('Spell', 'Heal');	
	$item->variable_row('Casts Per Day', 2);
	
	my ($enchantment) = $item->item_enchantments;
	
	# WHEN
	my $result = $enchantment->use($target);
	
	# THEN
	is($result->damage, 6, "Damaged recorded correctly");
	$target->discard_changes;
	is($target->hit_points, 10, "Target healed correctly");
	
	$self->unmock_dice;	
}

sub test_init : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['spell_casts_per_day'] );
	
	# WHEN
	
	# THEN
	my ($enchantment) = $item->item_enchantments;
	is(defined $enchantment->variable('Spell'), 1, "Spell name set");
	is($enchantment->variable('Casts Per Day') >= 1 && $enchantment->variable('Casts Per Day') <= 10, 1, 'Casts per day set correctly');
	is($enchantment->variable('Spell Level') >= 1 && $enchantment->variable('Casts Per Day') <= 20, 1, 'Spell level set correctly');	
}

sub test_tooltoip : Tests(1) {
	my $self = shift;
	
	# GIVEN
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['spell_casts_per_day'] );
	my ($enchantment) = $item->item_enchantments;
	$enchantment->variable('Spell', 'Heal');
	$enchantment->variable_max('Casts Per Day', 2);
	$enchantment->variable('Spell Level', 3);	
	
	# WHEN	
	my $tooltip = $enchantment->tooltip;
	
	# THEN
	is($tooltip, "Cast Heal (level 3) twice per day", "enchantment tooltip set correctly");  
		
}