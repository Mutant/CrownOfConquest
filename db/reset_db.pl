#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $db = 'game2';

my $dbh = DBI->connect("dbi:mysql:$db","root","root");

print "This will clear all tables in DB $db, are you sure? (Y/N) ";
my $res = <STDIN>;
exit unless $res eq "Y\n";

my @tables = qw(
Announcement_Player 
Battle_Participant 
Bomb
Building
Building_Upgrade
Capital_History 
Character
Character_Effect
Character_History
Character_Skill
Combat_Log
Combat_Log_Messages 
Creature
Creature_Effect
Creature_Group
Creature_Orb
Crown_History
Day
Day_Log
Day_Stats
Door 
Dungeon 
Dungeon_Grid 
Dungeon_Room 
Dungeon_Room_Param
Dungeon_Sector_Path
Dungeon_Sector_Path_Door 
Dungeon_Teleporter 
Dungeon_Wall 
Effect
Election
Election_Candidate
Garrison 
Garrison_Messages 
Global_News
Grave
Item_Enchantments
Item_Grid
Items  
Item_Variable 
Kingdom
Kingdom_Claim
Kingdom_Claim_Response
Kingdom_Messages 
Kingdom_Relationship
Kingdom_Town
Land
Mapped_Dungeon_Grid 
Mapped_Sectors
Memorised_Spells
Party
Party_Battle 
Party_Day_Stats
Party_Effect 
Party_Kingdom 
Party_Mayor_History 
Party_Messages
Party_Messages_Recipients
Party_Town 
Player 
Player_Reward_Links
Player_Reward_Vote
Player_Login 
Quest
Quest_Param
Quest_Param_Name
Response_Time
Road
sessions
Shop
Survey_Response 
Town
Town_Guards 
Town_History 
Town_Raid
Trade
Treasure_Chest
);

foreach my $table (@tables) {
    $dbh->do("CREATE TABLE `${table}_tmp` LIKE `$table`");
    $dbh->do("RENAME TABLE `$table` TO `${table}_old`, `${table}_tmp` TO `${table}`");
    $dbh->do("DROP TABLE `${table}_old`");
};
