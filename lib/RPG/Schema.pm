package RPG::Schema;

use strict;
use warnings;

use base qw/DBIx::Class::Schema/;

use Data::Dumper;
use Carp;

__PACKAGE__->load_classes(qw/
    Items Item_Category Race Item_Type Player Party Terrain Land Dimension Class Character Shop Items_Made
    Creature CreatureType CreatureGroup Town GameVars Equip_Places Item_Attribute Item_Attribute_Name
    Item_Variable Item_Variable_Params Item_Variable_Name Super_Category Equip_Place_Category Levels
    Spell Memorised_Spells Effect Creature_Effect Character_Effect Mapped_Sectors Day DayLog Combat_Log
    Quest Quest_Param Quest_Param_Name Quest_Type Character_History Grave Creature_Orb Party_Messages
    Dungeon Dungeon_Grid Dungeon_Wall Dungeon_Position Door Dungeon_Room Mapped_Dungeon_Grid Session
    Item_Property_Category Party_Town Party_Battle Battle_Participant Party_Effect Town_History Road
    Treasure_Chest Survey_Response Announcement Announcement_Player Tip Dungeon_Sector_Path
    Dungeon_Sector_Path_Door Garrison Combat_Log_Messages Garrison_Messages Enchantments Item_Enchantments
    Enchantment_Item_Category Creature_Category Promo_Code Promo_Org Town_Guards Election Election_Candidate
    Dungeon_Teleporter Dungeon_Special_Room Creature_Spell Building_Type Building Reward_Links Player_Reward_Links
    Kingdom Kingdom_Messages Party_Kingdom Party_Mayor_History
/);

my $config;
my $log;

sub connect {
	my $package = shift;
	$config = shift;
	
	my @connect_params = @_;
		
	unless (ref $config) {
	    unshift @connect_params, $config;
	    $config = undef;
	}
		
	return $package->SUPER::connect(@connect_params);		
}

sub config {
	my $package = shift;
	my $new_config = shift;

	$config = $new_config if defined $new_config;

	return $config;
}

sub log {
	my $package = shift;
	my $new_log = shift;
	
	$log = $new_log if defined $new_log;
	
	return $log;
}


1;
