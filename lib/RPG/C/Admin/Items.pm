package RPG::C::Admin::Items;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON;
use Data::Dumper;

sub main : Local {
	my ($self, $c) = @_;
	
	my @item_types = $c->model('Item_Type')->search(
		{},
		{
			order_by => 'item_type',
		},
	);
	
	my $item_type_to_edit;
	my @item_attribute_names;
	my @item_variable_names;
	if ($c->req->param('item_type_id')) {
		$item_type_to_edit = $c->model('Item_Type')->find(
			{
				item_type_id => $c->req->param('item_type_id'),
			},
			{
				prefetch => [
					{'item_attributes' => 'item_attribute_name'},
					'category',
					{'item_variable_params' => 'item_variable_name'},
				],
			},
		);

		@item_attribute_names = $c->model('Item_Attribute_Name')->search(
			{
				item_category_id => $item_type_to_edit->item_category_id,
			},
		);
		
		@item_variable_names = $c->model('Item_Variable_Name')->search(
			{
				item_category_id => $item_type_to_edit->item_category_id,
			},
		);
	}
		
	$c->forward('RPG::V::TT',
        [{
            template => 'admin/items/edit.html',
			params => {
				item_types => \@item_types,
				item_type_to_edit => $item_type_to_edit,
				item_attribute_names => \@item_attribute_names,
				item_variable_names => \@item_variable_names,
			},
        }]
    );
}

sub update_item_type : Local {
	my ($self, $c) = @_;
	
	my $item_type = $c->model('Item_Type')->find(
		{
			item_type_id => $c->req->param('item_type_id'),
		},
	);
	
	$item_type->base_cost($c->req->param('base_cost'));
	$item_type->prevalence($c->req->param('prevalence'));
	$item_type->update;
	
	my $params = $c->req->params;
	my @item_attribute_names = $c->model('Item_Attribute_Name')->search(
		{
			item_category_id => $item_type->item_category_id,
		},
	);
	
	foreach my $item_attribute_name (@item_attribute_names) {
		my $item_attribute = $c->model('DBIC::Item_Attribute')->find_or_create(
			{
				item_attribute_name_id => $item_attribute_name->id,
				item_type_id => $item_type->id,
			},
		);
		
		$item_attribute->item_attribute_value($params->{'attribute_'. $item_attribute_name->id});
		$item_attribute->update;
	}
	
	my @item_variable_names = $c->model('Item_Variable_Name')->search(
		{
			item_category_id => $item_type->item_category_id,
		},
	);
	
	foreach my $item_variable_name (@item_variable_names) {
		my $item_variable_param = $c->model('DBIC::Item_Variable_Params')->find_or_create(
			{
				item_variable_name_id => $item_variable_name->id,
				item_type_id => $item_type->id,

			},
		);
		
		$item_variable_param->keep_max($params->{'item_variable_param_keep_max_' . $item_variable_name->id});
		$item_variable_param->min_value($params->{'item_variable_param_min_' . $item_variable_name->id});
		$item_variable_param->max_value($params->{'item_variable_param_max_' . $item_variable_name->id});
		$item_variable_param->update;				
	}
	
	$c->forward('/admin/items/main');
}

1;