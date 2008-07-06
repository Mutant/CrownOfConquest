use strict;
use warnings;
  
package RPG::ResultSet::Equip_Places;
  
use base 'DBIx::Class::ResultSet';

use Carp;
use Data::Dumper;

# Returns an hash of arrays containing the names of categories allowed in each equip place
sub equip_place_category_list {
	my $self = shift;
	
	my @equip_places = $self->search(
		{},
		{
			prefetch => {'equip_place_categories' => 'item_category'},
		}
	);
	
	my %equip_place_category_list;
	
	foreach my $equip_place (@equip_places) {
		foreach my $eq_place_category ($equip_place->equip_place_categories) {
			push @{$equip_place_category_list{$equip_place->equip_place_name}}, $eq_place_category->item_category->item_category;
		} 	
	}
	
	warn Dumper \%equip_place_category_list;
	
	return %equip_place_category_list;	
}

1;