#!/usr/bin/perl

# This script will connect to a DB and dump the schema plus fixture data to file, e.g.
#  ./gen_schema.pl game-db /tmp/schema.sql

use strict;
use warnings;
use autodie;

my @fixture_tables = qw(
  Equip_Places
  Equip_Place_Category
  Class
  Race
  Spell
  Quest_Type
  Quest_Param_Name
  Levels
  Dungeon_Position
  Enchantments
  Dungeon_Special_Room
  Building_Type
  Skill
  Map_Tileset
  Building_Upgrade_Type
  Creature_Category
  Creature_Spell
  Creature_Type
  Super_Category
  Terrain
  Tip
  Item_Attribute
  Item_Attribute_Name
  Item_Category
  Item_Property_Category
  Item_Type
  Item_Variable_Name
  Item_Variable_Params
);

my $fixture_table_string = join ' ', @fixture_tables;

my $source_db = shift // die "Must provide a source DB name\n";
my $dump_file = shift // die "Must provide file name to dump schema to\n";

system("mysqldump -d $source_db > $dump_file");
system("mysqldump -t $source_db $fixture_table_string >> $dump_file");
