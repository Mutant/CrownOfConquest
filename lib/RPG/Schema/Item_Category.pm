package RPG::Schema::Item_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Category');

__PACKAGE__->add_columns(qw/item_category_id item_category super_category_id hidden auto_add_to_shop/);
__PACKAGE__->set_primary_key('item_category_id');

__PACKAGE__->has_many( 'item_types', 'RPG::Schema::Item_Type', { 'foreign.item_category_id' => 'self.item_category_id' } );

__PACKAGE__->has_many( 'item_attribute_names', 'RPG::Schema::Item_Attribute_Name', { 'foreign.item_category_id' => 'self.item_category_id' } );

__PACKAGE__->has_many( 'item_variable_names', 'RPG::Schema::Item_Variable_Name', { 'foreign.item_category_id' => 'self.item_category_id' } );

__PACKAGE__->belongs_to( 'super_category', 'RPG::Schema::Super_Category', { 'foreign.super_category_id' => 'self.super_category_id' } );

# Get a list of variable names in a property_category
my %variables_in_property_category;
sub variables_in_property_category {
    my $self                   = shift;
    my $property_category_name = shift;

    return @{ $variables_in_property_category{$property_category_name}{$self->id} }
        if ref $variables_in_property_category{$property_category_name}{$self->id} eq 'ARRAY';

    my @variables = map { $_->item_variable_name } $self->search_related(
        'item_variable_names',
        { 'property_category.category_name' => $property_category_name, },
        { join                              => ['property_category'], }
    );

    $variables_in_property_category{$property_category_name}{$self->id} = \@variables;

    return @variables;
}

1;
