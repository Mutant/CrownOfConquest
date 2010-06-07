package Test::RPG::ResultSet::Items;

use strict;
use warnings;

use base qw(Test::RPG::DB);

use Test::More;
use Test::RPG::Builder::Item_Type;

__PACKAGE__->runtests() unless caller();

sub startup : Tests(startup=>1) {
    my $self = shift;
    
    $self->unmock_dice;
    use_ok 'RPG::ResultSet::Items';
     
}

sub test_create_enchanted_0_enchantments : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantable => 1 );
	
	# WHEN
	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
            item_type_id   => $item_type->id,			
		},
	);
	
	# THEN
	isa_ok($item, 'RPG::Schema::Items', "Item created correctly");
	my @enchantments = $item->item_enchantments;	
	is(scalar @enchantments, 0, "No enchantments on item");	
}

sub test_create_enchanted_1_enchantment : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantable => 1 );
	
	# WHEN
	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
            item_type_id   => $item_type->id,			
		},
		{
			number_of_enchantments => 1,
		}		
	);
	
	# THEN
	isa_ok($item, 'RPG::Schema::Items', "Item created correctly");
	my @enchantments = $item->item_enchantments;	
	is(scalar @enchantments, 1, "One enchantment on item");

}

sub test_create_enchanted_non_enchantable_type : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantable => 0 );
	
	# WHEN
	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
            item_type_id   => $item_type->id,			
		},
		{
			number_of_enchantments => 1,
		}			
	);
	
	# THEN
	isa_ok($item, 'RPG::Schema::Items', "Item created correctly");
	my @enchantments = $item->item_enchantments;	
	is(scalar @enchantments, 0, "No enchantments on item");	
}

1;