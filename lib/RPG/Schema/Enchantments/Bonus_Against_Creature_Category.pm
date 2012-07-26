package RPG::Schema::Enchantments::Bonus_Against_Creature_Category;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use List::Util qw(shuffle);
use RPG::Maths;
use Lingua::EN::Inflect qw ( PL_N );

use Data::Dumper;

sub init_enchantment {
	my $self = shift;
	
	my @enchantments = $self->item->item_enchantments;
	my %cats_already_used;
	foreach my $enchantment (@enchantments) {
		if ($enchantment->variable('Creature Category')) {
			$cats_already_used{$enchantment->variable('Creature Category')} = 1; 	
		}	
	}
		
	my @categories = $self->result_source->schema->resultset('Creature_Category')->search();
	
	my $category = (shuffle grep { ! $cats_already_used{$_->id} } @categories)[0];
	
	$self->add_to_variables(
		{
			name => 'Creature Category',
			item_variable_value => $category->id,
			item_id => $self->item_id,
		},
	);
	
	my $bonus = RPG::Maths->weighted_random_number(1..5);
	$self->add_to_variables(
		{
			name => 'Bonus',
			item_variable_value => $bonus,
			item_id => $self->item_id,
		},
	);
}

sub is_usable {
	return 0;	
}

sub must_be_equipped {
	return 1;	
}

sub tooltip {
	my $self = shift;
	
	my $creature_cat = $self->creature_category->name;
	$creature_cat = PL_N($creature_cat) unless $creature_cat eq 'Undead';
	
	return '+' . $self->variable('Bonus') . ' vs ' . $creature_cat;
}

sub creature_category {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Creature_Category')->find($self->variable('Creature Category'));	
}

sub sell_price_adjustment {
	my $self = shift;
	
	return 70 * $self->variable('Bonus');	
}

1;