package RPG::Schema;

use strict;
use warnings;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_classes(qw/
    Items Item_Category Race Item_Type Player Party Terrain Land Dimension Class Character Shop Items_Made
    Creature CreatureType CreatureGroup Trait Town GameVars Equip_Places Item_Attribute Item_Attribute_Name
    Item_Variable Item_Variable_Params Item_Variable_Name Super_Category Equip_Place_Category Levels
    Spell Memorised_Spells Effect Creature_Effect Character_Effect Mapped_Sectors Day DayLog Combat_Log
    Quest Quest_Param Quest_Param_Name Quest_Type
/);

my $config;

sub connect {
	my $package = shift;
	$config = shift;
	
	return $package->SUPER::connect(@_);		
}

sub config {
	my $package = shift;
	my $new_config = shift;
	
	$config = $new_config if defined $new_config;
	
	return $config;
}

1;
