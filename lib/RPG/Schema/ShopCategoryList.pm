package RPG::Schema::ShopCategoryList;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->add_columns(qw/item_category_id item_category/);
__PACKAGE__->table('Item_Category');

# Complex DBIC stuff to get categories of items that a shop sells.
#  We need this because shops make items and sell individual items, so we need a union of 2 queries
#  DBIC doesn't support this in the usual way (see "Arbitrary SQL through a custom ResultSource" in the
#  DBIC cookbook
my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'ShopCategoryList' );
  
  # Hand in your query as a scalar reference
  # It will be added as a sub-select after FROM,
  # so pay attention to the surrounding brackets!
$new_source->name( \<<SQL );
  ( 
    SELECT me.item_category_id, me.item_category 
       FROM Item_Category me 
       LEFT JOIN Item_Type item_types ON ( item_types.item_category_id = me.item_category_id ) 
       LEFT JOIN Items_Made shops_with_item ON ( shops_with_item.item_type_id = item_types.item_type_id ) 
       WHERE ( shops_with_item.shop_id=? )

	UNION

    SELECT me.item_category_id, me.item_category 
       FROM Item_Category me 
       LEFT JOIN Item_Type item_types ON ( item_types.item_category_id = me.item_category_id ) 
       LEFT JOIN Items items ON ( items.item_type_id = item_types.item_type_id ) 
       WHERE ( items.shop_id = ? )
  )
SQL
  

RPG::Schema->register_source( 'ShopCategoryList' => $new_source );