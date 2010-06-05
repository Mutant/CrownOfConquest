use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Spells_Cast_Per_Day;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;

sub test_use : Tests() {
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
	
	$self->{dice}->unfake_module();
		
}