package RPG::Schema::Item_Attribute;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Attribute');

__PACKAGE__->add_columns(qw/item_attribute_id item_attribute_name_id item_attribute_value item_type_id/);
__PACKAGE__->set_primary_key('item_attribute_id');

__PACKAGE__->belongs_to(
    'item_type',
    'RPG::Schema::Item_Type',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->belongs_to(
    'item_attribute_name',
    'RPG::Schema::Item_Attribute_Name',
    { 'foreign.item_attribute_name_id' => 'self.item_attribute_name_id' }
);

sub value {
	my $self = shift;
	
	return $self->item_attribute_value;	
}

sub formatted_value {
	my $self = shift;
	
	my $item_attribute_name = $self->item_attribute_name;
	
	if ($item_attribute_name->value_type eq 'boolean') {
		return $self->value ? 'Yes' : 'No';
	}
	elsif ($item_attribute_name->value_type eq 'item_type') {
		# TODO: maybe pass in a list of item types?
		my $item_type = $self->result_source->schema->resultset('Item_Type')->find(
			{
				item_type_id => $self->value,
			}
		);
		
		return $item_type->item_type;
	}
	else {
		return $self->value;
	}
}

1;