use strict;
use warnings;
  
package RPG::ResultSet::Items;
  
use base 'DBIx::Class::ResultSet';

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

1;