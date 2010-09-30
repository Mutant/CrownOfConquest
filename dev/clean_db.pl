#!/usr/bin/perl

use strict;
use warnings;

use DBI;

# Clean a DB so it's suitable for checking in as a schema for dev purposes
#  Just deletes all the data out of a bunch of tables (mostly)
my @tables_to_delete = qw(	
	Announcement
	Announcement_Player
	Battle_Participant
	`Character`
	Character_Effect
	Character_History
	Combat_Log
	Combat_Log_Messages
	Creature
	Creature_Effect
	Creature_Group
	Day_Log
	Effect
	Garrison
	Garrison_Messages
	Grave
	Item_Enchantments
	Item_Variable
	Items
	Mapped_Dungeon_Grid
	Mapped_Sectors
	Memorised_Spells
	Party
	Party_Battle
	Party_Effect
	Party_Messages
	Party_Town
	Player
	Quest
	Quest_Param
	Survey_Response
	Town_History
	sessions
);

my $dbh = DBI->connect("dbi:mysql:gametmp","root","");
$dbh->do('SET FOREIGN_KEY_CHECKS=0');

foreach my $table (@tables_to_delete) {
	#warn "delete from $table";
	$dbh->do("delete from $table");	
}