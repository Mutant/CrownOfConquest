use strict;
use warnings;

package Test::RPG::Builder::Item;

use Carp;

sub build_item {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $super_cat = $schema->resultset('Super_Category')->create( { super_category_name => $params{super_category_name} || 'Test1', } );

    my $item_cat = $schema->resultset('Item_Category')->find_or_create(
        {
            item_category     => $params{category_name} || 'SubCat1',
            super_category_id => $super_cat->id,
        }
    );
	
	my $item_type_id = $params{item_type_id} || '';

	unless ($item_type_id) {
	    my $item_type = $schema->resultset('Item_Type')->find_or_create(
	        {
	            item_type        => 'Test1',
	            item_category_id => $item_cat->id,
	            base_cost => $params{base_cost} // 1,
	        }
	    );
	    
	    $item_type_id = $item_type->id;
	}

    my $eq_place = $schema->resultset('Equip_Places')->find(1);

    my $item = $schema->resultset('Items')->create(
        {
            item_type_id   => $item_type_id,
            character_id   => $params{char_id} || undef,
            treasure_chest_id => $params{treasure_chest_id} || undef,
            equip_place_id => $eq_place->id,
            name => $params{name} || '',
            shop_id => $params{shop_id} || undef,
            garrison_id => $params{garrison_id} || undef,
        }
    );

    foreach my $variable ( @{ $params{variables} } ) {
        my $ivn = $schema->resultset('Item_Variable_Name')->find_or_create(
            {
                item_variable_name => $variable->{item_variable_name},
                item_category_id   => $item_cat->id,
            }
        );

        $schema->resultset('Item_Variable')->create(
            {
                item_variable_name_id => $ivn->id,
                item_variable_value   => $variable->{item_variable_value},
                max_value             => $variable->{max_value} || $variable->{item_variable_value},
                item_id               => $item->id,
            }
        );
    }

    foreach my $attribute ( @{ $params{attributes} } ) {
        my $ian = $schema->resultset('Item_Attribute_Name')->find_or_create(
            {
                item_attribute_name => $attribute->{item_attribute_name},
                item_category_id    => $item_cat->id,
            }
        );

        $schema->resultset('Item_Attribute')->create(
            {
                item_attribute_name_id => $ian->id,
                item_type_id           => $item_type_id,
                item_attribute_value   => $attribute->{item_attribute_value},
            }
        );
    }
    
    foreach my $enchantment ( @{ $params{enchantments} } ) {
    	my $enchantment_rec = $schema->resultset('Enchantments')->find(
    		{
    			enchantment_name => $enchantment,
    		}
    	);
    	
    	confess "Enchantment $enchantment not found!" unless $enchantment_rec;
    	
    	$schema->resultset('Item_Enchantments')->create(
    		{
    			enchantment_id => $enchantment_rec->id,
    			item_id => $item->id,
    		}
    	);
    }

    return $item;
}

1;
