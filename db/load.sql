/*
SQLyog - Free MySQL GUI v5.19
Host - 4.1.11-Debian_4sarge2-log : Database - game
*********************************************************************
Server version : 4.1.11-Debian_4sarge2-log
*/


SET NAMES utf8;

SET SQL_MODE='';

SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO';

/*Data for the table `Character` */

insert into `Character` (`character_id`,`character_name`,`xp`,`strength`,`intelligence`,`agility`,`divinity`,`constitution`,`hit_points`,`level`,`magic_points`,`faith_points`,`max_hit_points`,`max_magic_points`,`max_faith_points`,`party_id`,`class_id`,`race_id`) values (1,'Mutant',0,20,5,15,5,20,0,0,0,0,4,0,0,1,1,1);
insert into `Character` (`character_id`,`character_name`,`xp`,`strength`,`intelligence`,`agility`,`divinity`,`constitution`,`hit_points`,`level`,`magic_points`,`faith_points`,`max_hit_points`,`max_magic_points`,`max_faith_points`,`party_id`,`class_id`,`race_id`) values (2,'Bob the Brave',0,15,7,12,11,20,0,0,0,0,11,0,0,1,1,3);
insert into `Character` (`character_id`,`character_name`,`xp`,`strength`,`intelligence`,`agility`,`divinity`,`constitution`,`hit_points`,`level`,`magic_points`,`faith_points`,`max_hit_points`,`max_magic_points`,`max_faith_points`,`party_id`,`class_id`,`race_id`) values (3,'Hawkeye',0,11,17,16,10,11,0,0,0,0,2,0,0,1,2,2);
insert into `Character` (`character_id`,`character_name`,`xp`,`strength`,`intelligence`,`agility`,`divinity`,`constitution`,`hit_points`,`level`,`magic_points`,`faith_points`,`max_hit_points`,`max_magic_points`,`max_faith_points`,`party_id`,`class_id`,`race_id`) values (4,'Holy Man',0,9,11,11,20,14,0,0,0,0,3,0,9,1,3,3);
insert into `Character` (`character_id`,`character_name`,`xp`,`strength`,`intelligence`,`agility`,`divinity`,`constitution`,`hit_points`,`level`,`magic_points`,`faith_points`,`max_hit_points`,`max_magic_points`,`max_faith_points`,`party_id`,`class_id`,`race_id`) values (5,'Mandrake the Magnificent',0,7,20,10,15,13,0,0,0,0,3,2,0,1,4,2);

/*Data for the table `Class` */

insert into `Class` (`class_id`,`class_name`) values (1,'Warrior');
insert into `Class` (`class_id`,`class_name`) values (2,'Archer');
insert into `Class` (`class_id`,`class_name`) values (3,'Priest');
insert into `Class` (`class_id`,`class_name`) values (4,'Mage');

/*Data for the table `Item_Category` */

insert into `Item_Category` (`item_category_id`,`item_category`) values (1,'Weapons');
insert into `Item_Category` (`item_category_id`,`item_category`) values (2,'Armour');

/*Data for the table `Item_Type` */

insert into `Item_Type` (`item_type_id`,`item_type`,`basic_modifier`,`item_category_id`) values (1,'Short Sword',0,1);
insert into `Item_Type` (`item_type_id`,`item_type`,`basic_modifier`,`item_category_id`) values (2,'Long Sword',0,1);
insert into `Item_Type` (`item_type_id`,`item_type`,`basic_modifier`,`item_category_id`) values (3,'Leather Armour',0,2);
insert into `Item_Type` (`item_type_id`,`item_type`,`basic_modifier`,`item_category_id`) values (4,'Chain Mail',0,2);

/*Data for the table `Items` */

/*Data for the table `Items_In_Shop` */

insert into `Items_In_Shop` (`shop_id`,`item_type_id`) values (1,1);
insert into `Items_In_Shop` (`shop_id`,`item_type_id`) values (1,2);
insert into `Items_In_Shop` (`shop_id`,`item_type_id`) values (1,3);
insert into `Items_In_Shop` (`shop_id`,`item_type_id`) values (1,4);

/*Data for the table `Land` */

/*Data for the table `Party` */

insert into `Party` (`party_id`,`name`,`gold`,`player_id`,`land_id`) values (1,'Mutant\'s Mob',100,1,0);
insert into `Party` (`party_id`,`name`,`gold`,`player_id`,`land_id`) values (2,'',0,NULL,NULL);

/*Data for the table `Player` */

insert into `Player` (`player_id`,`player_name`,`email`,`password`) values (1,'Mutant','mutant.nz@gmail.com','pass');

/*Data for the table `Race` */

insert into `Race` (`race_id`,`race_name`,`base_int`,`base_str`,`base_agl`,`base_con`,`base_div`) values (1,'Human',5,5,5,5,5);
insert into `Race` (`race_id`,`race_name`,`base_int`,`base_str`,`base_agl`,`base_con`,`base_div`) values (2,'Elf',7,4,6,3,5);
insert into `Race` (`race_id`,`race_name`,`base_int`,`base_str`,`base_agl`,`base_con`,`base_div`) values (3,'Dwarf',3,5,4,7,6);

/*Data for the table `Shop` */

insert into `Shop` (`shop_id`,`land_id`,`shop_name`) values (1,0,'New Party Shop');

/*Data for the table `Terrain` */
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (1,'road','',0);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (2,'plain','',0);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (3,'foot hill','',1);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (4,'field','',0);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (5,'light forest','',1);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (6,'dense forest','',2);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (7,'hill','',2);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (8,'mountain','',3);
insert into `Terrain` (`terrain_id`,`terrain_name`,`image`,`modifier`) values (9,'marsh','',3);

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
