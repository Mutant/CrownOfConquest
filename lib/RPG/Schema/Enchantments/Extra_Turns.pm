package RPG::Schema::Enchantments::Extra_Turns;

use Moose::Role;

use RPG::Maths;
use Games::Dice::Advanced;

with 'RPG::Schema::Enchantments::Interface';

sub init_enchantment {
	my $self = shift;

	my $turns = RPG::Maths->weighted_random_number( 1 .. 20 );

	$self->add_to_variables(
		{
			name                => 'Extra Turns',
			item_variable_value => $turns,
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

	my $tip = 'Adds ' . $self->variable('Extra Turns') . ' extra turns each day';
	$tip .= ' (Must be equipped)' if $self->must_be_equipped;
	
	return $tip;
}

sub sell_price_adjustment {
	my $self = shift;

	return 115 * $self->variable('Extra Turns') + ( $self->must_be_equipped ? 0 : 700 );
}

sub new_day {
	my $self    = shift;
	my $context = shift;

	my $item = $self->item;
	
	if ( my $char = $item->belongs_to_character ) {
		return if !$item->equipped && $self->must_be_equipped;
		
		return if $char->is_dead || defined $char->status && $char->status eq 'inn';

		my $party = $char->party;

		return if ! $party || $party->turns >= $context->config->{maximum_turns};
		
		return if $party->bonus_turns_today >= $context->config->{maximum_bonus_turns};
		
		my $turns_to_add = $self->variable('Extra Turns');
		
		if ($party->bonus_turns_today + $turns_to_add >= $context->config->{maximum_bonus_turns}) {
		    $turns_to_add = $context->config->{maximum_bonus_turns} - $party->bonus_turns_today;
		}

		$party->increase_turns( $turns_to_add + $party->turns );
		$party->increase_bonus_turns_today($turns_to_add);
		
		$party->update;

		$party->add_to_day_logs(
			{
				day_id => $context->current_day->id,
				log    => 'You received ' 
					. $self->variable('Extra Turns') 
					. ' extra turns from ' 
					. $char->name . "'s"
					. ' '
					. $item->display_name,
			}
		);
	}
}

1;
