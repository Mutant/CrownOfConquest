use strict;
use warnings;

package Test::RPG::Builder::Item;

sub build_item {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $super_cat = $schema->resultset('Super_Category')->create( { super_category_name => $params{super_category_name} || 'Test1', } );

    my $item_cat = $schema->resultset('Item_Category')->create(
        {
            item_category     => $params{category_name} || 'SubCat1',
            super_category_id => $super_cat->id,
        }
    );

    my $item_type = $schema->resultset('Item_Type')->create(
        {
            item_type        => 'Test1',
            item_category_id => $item_cat->id,
        }
    );

    my $eq_place = $schema->resultset('Equip_Places')->find(1);

    my $item = $schema->resultset('Items')->create(
        {
            item_type_id   => $item_type->id,
            character_id   => $params{char_id} || undef,
            equip_place_id => $eq_place->id,
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
                item_type_id           => $item_type->id,
                item_attribute_value   => $attribute->{item_attribute_value},
            }
        );
    }

    return $item;
}

1;
