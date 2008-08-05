use strict;
use warnings;

package Test::RPG::Schema::Items;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

sub startup : Tests(startup=>1) {
	use_ok('RPG::Schema::Items');
}

sub setup_data : Tests(setup) {
	my $self = shift;
	
	$self->{item_attribute_name} = $self->{schema}->resultset('Item_Attribute_Name')->create({
		item_attribute_name => 'Test1',
		item_category_id => 1,
	});
	
	$self->{item_type} = $self->{schema}->resultset('Item_Type')->create({
		item_type => 'Test1',
		item_category_id => 1,
	});	
	
	$self->{item_attribute} = $self->{schema}->resultset('Item_Attribute')->create({
		item_attribute_name_id => $self->{item_attribute_name}->id,
		item_attribute_value => 99,
		item_type_id => $self->{item_type}->id,
	});
	
	$self->{item_variable_name_1} = $self->{schema}->resultset('Item_Variable_Name')->create({
		item_variable_name => 'Var1',
		item_category_id => 1,
	});
	
	$self->{item_variable_name_2} = $self->{schema}->resultset('Item_Variable_Name')->create({
		item_variable_name => 'Var2',
		item_category_id => 1,
	});
	
	$self->{item_variable_param_1} = $self->{schema}->resultset('Item_Variable_Params')->create({
		item_type_id => $self->{item_type}->id,
		min_value => 1,
		max_value => 10,
		keep_max => 0,
		item_variable_name_id => $self->{item_variable_name_1}->id,		
	});

	$self->{item_variable_param_2} = $self->{schema}->resultset('Item_Variable_Params')->create({
		item_type_id => $self->{item_type}->id,
		min_value => 5,
		max_value => 8,
		keep_max => 1,
		item_variable_name_id => $self->{item_variable_name_2}->id,		
	});
			
	$self->{item} = $self->{schema}->resultset('Items')->create({
		item_type_id => $self->{item_type}->id,
	});
}

sub delete_data : Tests(teardown) {
	my $self = shift;
		
	$self->{item_attribute_name}->delete;
	$self->{item_type}->delete;
	$self->{item_attribute}->delete;
	$self->{item}->delete;
	$self->{item_variable_name_1}->delete;
	$self->{item_variable_name_2}->delete;
	$self->{item_variable_param_1}->delete;
	$self->{item_variable_param_2}->delete;
}

sub test_attribute : Tests(1) {
	my $self = shift;
	
	is($self->{item}->attribute('Test1')->item_attribute_value, 99, "Item attribute value returned");
}

sub test_variable_params_created : Tests(5) {
	my $self = shift;
	
	my @item_variables = $self->{item}->item_variables;
	
	my $val1 = $self->{item}->variable_row('Var1');
	ok($val1->item_variable_value >= 1 && $val1->item_variable_value <= 10, "Var1 in correct range");
	is($val1->max_value, undef, "Max value not set for var1");

	my $val2 = $self->{item}->variable_row('Var2');
	ok($val2->item_variable_value >= 5 && $val2->item_variable_value <= 8, "Var2 in correct range");
	is($val2->max_value, $val2->item_variable_value, "Max value set for var2");	
	
	my $val1_value = $self->{item}->variable('Var1');
	ok($val1_value >= 1 && $val1_value <= 10, "Got variable value directly");
	
}

1;