use strict;
use warnings;

package Test::RPG::Builder::Item_Type;

use Carp;

sub build_item_type {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $super_cat = $schema->resultset('Super_Category')->create( { super_category_name => $params{super_category_name} || 'Test1', } );

    my $item_cat = $schema->resultset('Item_Category')->find_or_create(
        {
            item_category => $params{category_name} || 'SubCat1',
            super_category_id => $super_cat->id,
            always_enchanted => $params{always_enchanted} // 0,
        }
    );

    if ( $params{equip_places_allowed} ) {
        foreach my $equip_place ( @{ $params{equip_places_allowed} } ) {
            my $equip_place_record = $schema->resultset('Equip_Places')->find(
                {
                    equip_place_name => $equip_place,
                }
            );

            $schema->resultset('Equip_Place_Category')->create(
                {
                    equip_place_id   => $equip_place_record->id,
                    item_category_id => $item_cat->id,
                }
            );
        }
    }

    if ( $params{enchantments} ) {
        foreach my $enchantment_type ( @{ $params{enchantments} } ) {
            my $enchantment = $schema->resultset('Enchantments')->find(
                {
                    enchantment_name => $enchantment_type,
                }
            );

            confess "Can't find enchantment $enchantment_type" unless $enchantment;

            $schema->resultset('Enchantment_Item_Category')->create(
                {
                    enchantment_id   => $enchantment->id,
                    item_category_id => $item_cat->id,
                }
            );
        }
    }

    my $item_type = $schema->resultset('Item_Type')->find_or_create(
        {
            item_type => $params{item_type} || 'Test1',
            item_category_id => $item_cat->id,
            prevalence       => $params{prevalence} || 10,
            base_cost        => $params{base_cost} || 0,
            weight           => $params{weight} || 0,
        }
    );

    if ( $params{variables} ) {
        foreach my $variable ( @{ $params{variables} } ) {
            my $ivn = $schema->resultset('Item_Variable_Name')->create(
                {
                    item_variable_name => $variable->{name},
                    create_on_insert   => $variable->{create_on_insert} || 0,
                    item_category_id   => $item_cat->id,
                }
            );

            $schema->resultset('Item_Variable_Params')->create(
                {
                    item_variable_name_id => $ivn->id,
                    item_type_id          => $item_type->id,
                    keep_max              => $variable->{keep_max} || 0,
                    min_value             => $variable->{min_value} || 0,
                    max_value             => $variable->{max_value} || 100,
                    special               => $variable->{special} // 0,
                }
            );
        }
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

    return $item_type;

}

1;
