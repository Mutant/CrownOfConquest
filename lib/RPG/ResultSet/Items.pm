use strict;
use warnings;
  
package RPG::ResultSet::Items;
  
use base 'DBIx::Class::ResultSet';

use List::Util qw(shuffle);

sub party_items_requiring_repair {
    my $self = shift;
    my $party_id = shift;
    my $only_eqipped_items = shift // 0;
    
    my %extra_params;
    $extra_params{equip_place_id} = {'!=',undef} if $only_eqipped_items;
    
    return $self->search(
        {
            'item_variables.item_variable_value' => \'< item_variables.max_value',
            'item_variable_name.item_variable_name' => 'Durability',
            'belongs_to_character.party_id'         => $party_id,
            %extra_params,
        },
        { join => [ { 'item_variables' => 'item_variable_name' }, 'belongs_to_character' ], }
    );   
}

sub create_enchanted {
	my $self = shift;
	my $params = shift;
	my $extra_params = shift;
		
	my $item = $self->create($params);
	
	return $item if ! defined $extra_params->{number_of_enchantments} || $extra_params->{number_of_enchantments} == 0;
		
	my @possible_enchantments = $self->result_source->schema->resultset('Enchantments')->search(
		{
			'categories.item_category_id' => $item->item_type->item_category_id,
		},
		{
			join => 'categories',
		}
	);

	return $item unless @possible_enchantments;
	
	for (1 .. $extra_params->{number_of_enchantments}) {
		last unless @possible_enchantments;

		@possible_enchantments = shuffle @possible_enchantments;		
		
		my $enchantment = $possible_enchantments[0];
		
		shift @possible_enchantments if $enchantment->one_per_item;
		
		$item->add_to_item_enchantments(
			{
				enchantment_id => $enchantment->id,
			}
		); 
	}
	
	return $item;	
}

1;