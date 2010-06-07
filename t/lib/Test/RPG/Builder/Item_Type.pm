use strict;
use warnings;

package Test::RPG::Builder::Item_Type;

sub build_item_type {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $super_cat = $schema->resultset('Super_Category')->create( { super_category_name => $params{super_category_name} || 'Test1', } );

    my $item_cat = $schema->resultset('Item_Category')->find_or_create(
        {
            item_category     => $params{category_name} || 'SubCat1',
            super_category_id => $super_cat->id,
            enchantable => $params{enchantable} || 0,
        }
    );

    my $item_type = $schema->resultset('Item_Type')->find_or_create(
        {
            item_type        => $params{item_type} || 'Test1',
            item_category_id => $item_cat->id,
            prevalence => $params{prevalence} || 10,
            base_cost => $params{base_cost} || 0,
        }
    );

}

1;