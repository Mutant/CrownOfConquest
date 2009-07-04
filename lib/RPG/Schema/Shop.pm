package RPG::Schema::Shop;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Shop');


__PACKAGE__->add_columns(
    'shop_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'shop_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'shop_owner_name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'shop_owner_name',
      'is_nullable' => 0,
      'size' => '255'
    },
    'shop_suffix' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'shop_suffix',
      'is_nullable' => 0,
      'size' => '40'
    },
    'town_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 1,
      'name' => 'land_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'cost_modifier' => {
      'data_type' => 'float',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'cost_modifier',
      'is_nullable' => 0,
      'size' => '11'
    },
    'status' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'status',
      'is_nullable' => 0,
      'size' => '20'
    },    
    'shop_size' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'shop_size',
      'is_nullable' => 0,
      'size' => '11'
    },    
);
__PACKAGE__->set_primary_key('shop_id');

__PACKAGE__->has_many(
    'items_made',
    'RPG::Schema::Items_Made',
    { 'foreign.shop_id' => 'self.shop_id' }
);

__PACKAGE__->many_to_many(
    'item_types',
    'RPG::Schema::Items_Type',
    'items_made',
);

__PACKAGE__->has_many(
    'items_in_shop',
    'RPG::Schema::Items',
    { 'foreign.shop_id' => 'self.shop_id' }
);

__PACKAGE__->belongs_to(
    'in_town',
    'RPG::Schema::Town',
    { 'foreign.town_id' => 'self.town_id' }
);

sub item_types_made {
	my $self = shift;
	
	my @records = $self->search_related('items_made',
		{},
		{
			prefetch => {'item_type' => 'category'},			
		}
	);
	
	return map { $_->item_type } @records;
}

sub grouped_items_in_shop {
	my $self = shift;
	
	return $self->search_related('items_in_shop',
		{
		},
		{
			prefetch => {'item_type' => 'category'},
			+select => [ {'count' => '*'}, 'me.item_id', 'item_type.item_type_id' ],
			+as => [ 'number_of_items', 'item_id', 'item_type_id' ],
			group_by => 'item_type',
			order_by => 'item_category',
		},
	);
}

sub shop_name {
	my $self = shift;
	
	return $self->shop_owner_name . "'s " . $self->shop_suffix;	
}

1;