package RPG::Schema::Items;
use base 'DBIx::Class';
use strict;
use warnings;

use Games::Dice::Advanced;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Items');

__PACKAGE__->add_columns(
    'item_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'item_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'item_type_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 1,
      'name' => 'item_type_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'magic_modifier' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'magic_modifier',
      'is_nullable' => 0,
      'size' => '11'
    },
    'name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'name',
      'is_nullable' => 1,
      'size' => '255'
    },    
    'character_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'character_id',
      'is_nullable' => 1,
      'size' => '11'
    },
    'shop_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'shop_id',
      'is_nullable' => 0,
      'size' => '11'
    },        
    'equip_place_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'equip_place_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    
);
__PACKAGE__->set_primary_key('item_id');

__PACKAGE__->belongs_to(
    'item_type',
    'RPG::Schema::Item_Type',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->belongs_to(
    'in_shop',
    'RPG::Schema::Shop',
    { 'foreign.shop_id' => 'self.shop_id' }
);

__PACKAGE__->belongs_to(
    'equipped_in',
    'RPG::Schema::Equip_Places',
    { 'foreign.equip_place_id' => 'self.equip_place_id' }
);

__PACKAGE__->has_many(
    'item_variables',
    'RPG::Schema::Item_Variable',
    { 'foreign.item_id' => 'self.item_id' }
);

sub attribute {
	my $self = shift;
	my $attribute = shift;
	
	return $self->item_type->attribute($attribute); 	
}

sub variable {
	my $self = shift;
	my $variable_name = shift;
	my $new_val = shift;
	
	$self->{variables} = { map { $_->item_variable_name => $_ } $self->item_variables }
		unless $self->{variables};
	
	my $variable = $self->{variables}{$variable_name};
	
	return unless $variable;
	
	if ($new_val) {
		$variable->item_variable_value($new_val);
		$variable->update;	
	}
	
	return $variable->item_variable_value;
}

sub display_name {
	my $self = shift;
	
	my $quantity_string = '';
	if (my $quantity = $self->variable('Quantity')) {
		$quantity_string = ' (x' . $quantity  . ')';
	}
	
	return $self->item_type->item_type . $quantity_string . ' (' . $self->id . ')';
}

# Override insert to populate item_variable data
sub insert {
    my ( $self, @args ) = @_;
    
    $self->next::method(@args);
    
    my @item_variable_params = $self->item_type->search_related('item_variable_params',
    	{
    	},
    	{
    		prefetch => 'item_variable_name',
    	},
    );
    
    foreach my $item_variable_param (@item_variable_params) {
    	my $range = $item_variable_param->max_value - $item_variable_param->min_value - 1;
    	my $init_value = Games::Dice::Advanced->roll("1d$range") + $item_variable_param->min_value - 1;
    	$self->add_to_item_variables({
    		item_variable_name => $item_variable_param->item_variable_name->item_variable_name,
    		item_variable_value => $init_value,
    		max_value => $item_variable_param->keep_max ? $init_value : undef,
    	});
    }
    
	return $self;
}

sub sell_price {
	my $self = shift;
	my $shop = shift;
	
	my $modifier = $shop ? RPG->config->{shop_sell_modifier} : 0;
	
	my $price = int ($self->item_type->modified_cost($shop) / (100 / (100 + $modifier)));

	$price = 1 if $price == 0;
		
	$price *= $self->variable('Quantity') if $self->variable('Quantity');
	
	return $price;
}

1;