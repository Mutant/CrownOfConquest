package RPG::Schema::Shop;
use base 'DBIx::Class';

use Moose;

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

__PACKAGE__->has_many('items', 'RPG::Schema::Items', 'shop_id');

__PACKAGE__->has_many('item_sectors', 'RPG::Schema::Item_Grid', {'foreign.owner_id' => 'self.shop_id'}, { where => { owner_type => 'shop' } });

__PACKAGE__->belongs_to(
    'in_town',
    'RPG::Schema::Town',
    { 'foreign.town_id' => 'self.town_id' }
);

with qw/RPG::Schema::Role::Item_Grid/;

sub organise {
    my $self = shift;
    
    my @items = $self->search_related('items',
        {
            'equip_place_id' => undef,
        },
        {
            prefetch => {'item_type' => 'category'},
            order_by => 'category.item_category, me.item_id',            
        }
    );
        
    my @organised;
    my @special;
    foreach my $item (@items) {
        if (! $item->enchantments_count && ! $item->upgraded) {
            push @organised, $item;
        }
        else {
            push @special, $item;
        }
    }
    
    $self->organise_items_in_tabs({owner_type => 'shop', width => 12, height => 8 }, @organised, @special);
}

sub grouped_items_in_shop {
	my $self = shift;
	
	my @items = $self->search_related('items_in_shop',
		{
			'item_enchantments.enchantment_id' => undef,
		},
		{
			prefetch => {'item_type' => 'category'},
			'+select' => [ {'count' => '*'} ],
			'+as' => [ 'number_of_items' ],
			group_by => 'item_type',
			order_by => 'item_category',
			join => 'item_enchantments',
		},
	);
	
	@items = grep { ! $_->upgraded } @items;
	
	return @items;
}

sub has_enchanted_items {
	my $self = shift;
	
	my $enchanted = $self->search_related('items_in_shop',
		{
			'item_enchantments.enchantment_id' => {'!=', undef},
		},
		{
			join => 'item_enchantments',
		}
	)->count > 0 ? 1 : 0;
	
	my $upgraded = $self->search_related('items_in_shop',
		{
			'property_category.category_name' => 'Upgrade',
			'item_variables.item_variable_value' => {'>',0},
		},	
		{
			join => [
				{'item_variables' => {'item_variable_name' => 'property_category'}},
			],
		},
	)->count > 0 ? 1 : 0;
	
	
	return $enchanted || $upgraded;	
}

sub enchanted_items_in_shop {
	my $self = shift;
	
	my @enchanted = $self->search_related('items_in_shop',
		{
			'item_enchantments.enchantment_id' => {'!=', undef},
		},
		{
			prefetch => [
				'item_enchantments', 
				{'item_type' => 'category'},
			],
		}
	);
	
	my @upgraded = $self->search_related('items_in_shop',
		{
			'property_category.category_name' => 'Upgrade',
			'item_variables.item_variable_value' => {'>',0},
		},	
		{
			prefetch => [
				{'item_type' => 'category'},
				{'item_variables' => {'item_variable_name' => 'property_category'}},
			],
		},
	);
	
	my %found;
	my @items = grep { $found{$_->id}++; $found{$_->id}-1 == 0 ? 1 : 0 } (@enchanted, @upgraded);
	
	return sort { $a->item_type->category->item_category cmp $b->item_type->category->item_category } @items;
			
}

sub shop_name {
	my $self = shift;
	
	return $self->shop_owner_name . "'s " . $self->shop_suffix;	
}

1;