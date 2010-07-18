ALTER TABLE `Dungeon` ADD COLUMN `type` VARCHAR(255)  NOT NULL AFTER `name`;
update Dungeon set type='dungeon';

insert into `Creature_Category` (name) values ('Guards');

insert into `Creature_Type` ('creature_type', 'level', 'weapon', 'fire', 'ice', 'poison', 'creature_category_id') 
	values ('Rookie Town Guard', 6, 'Melee Weapon', 18, 18, 18, (select creature_category_id from `Creature_Category` where name = 'Gaurds'));

insert into `Creature_Type` ('creature_type', 'level', 'weapon', 'fire', 'ice', 'poison', 'creature_category_id') 
	values ('Seasoned Town Guard', 12, 'Melee Weapon', 36, 36, 36, select creature_category_id from `Creature_Category` where name = 'Gaurds'));

insert into `Creature_Type` ('creature_type', 'level', 'weapon', 'fire', 'ice', 'poison', 'creature_category_id') 
	values ('Veteran Town Guard', 16, 'Melee Weapon', 48, 48, 48, select creature_category_id from `Creature_Category` where name = 'Gaurds'));

ALTER TABLE `Dungeon_Grid` MODIFY COLUMN `dungeon_grid_id` BIGINT  NOT NULL AUTO_INCREMENT;

ALTER TABLE `Treasure_Chest` ADD COLUMN `gold` INTEGER  NOT NULL DEFAULT 0 AFTER `trap`;

ALTER TABLE `Party_Town` ADD COLUMN `last_raid_start` DATETIME  DEFAULT NULL AFTER `prestige`,
 ADD COLUMN `last_raid_end` DATETIME  DEFAULT NULL AFTER `last_raid_start`;

ALTER TABLE `Quest` MODIFY COLUMN `quest_id` BIGINT  NOT NULL AUTO_INCREMENT;

