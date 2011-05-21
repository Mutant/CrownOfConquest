package RPG::Schema::Enchantments::Daily_Heal;

use Moose::Role;

use RPG::Maths;
use Games::Dice::Advanced;

with 'RPG::Schema::Enchantments::Interface';

sub init_enchantment {
	my $self = shift;

	my $heal = RPG::Maths->weighted_random_number( 1 .. 15 );

	$self->add_to_variables(
		{
			name                => 'Daily Heal',
			item_variable_value => $heal,
			item_id             => $self->item_id,
		},
	);

	my $equip_roll = Games::Dice::Advanced->roll('1d100');
	$self->add_to_variables(
		{
			name                => 'Must Be Equipped',
			item_variable_value => $equip_roll > 90 ? 0 : 1,
			item_id             => $self->item_id,
		},
	);

}

sub is_usable {
	return 0;
}

sub must_be_equipped {
	my $self = shift;

	return $self->variable('Must Be Equipped');
}

sub tooltip {
	my $self = shift;

	my $tip = 'Heals ' . $self->variable('Daily Heal') . ' hps per day';
	$tip .= ' (Must be equipped)' if $self->must_be_equipped;
	
	return $tip;
}

sub sell_price_adjustment {
	my $self = shift;

	return 45 * ($self->variable('Daily Heal') // 1) + ( $self->must_be_equipped ? 0 : 125 );
}

sub new_day {
	my $self = shift;
	my $context = shift;
	
	my $item = $self->item;

	if ( my $char = $item->belongs_to_character ) {
		return if ! $item->equipped && $self->must_be_equipped;
		
		my $actual = $char->change_hit_points( $self->variable('Daily Heal') );
		
		if ($actual) {
			$char->update;
			
			$char->party->add_to_day_logs(
		        {
		            day_id => $context->current_day->id,
		            log    => $char->name . " was healed " . $actual . " hit points by " . $char->pronoun('posessive-subjective') 
		            			. ' ' . $item->display_name,
		        }
	    	) if $char->party_id;
		}
		
	}
}

1;
