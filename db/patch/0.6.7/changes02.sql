ALTER TABLE `Garrison` ADD COLUMN `name` VARCHAR(100)  DEFAULT NULL AFTER `gold`;

ALTER TABLE `Garrison` MODIFY COLUMN `land_id` INTEGER  DEFAULT NULL;

ALTER TABLE `Party_Town` ADD COLUMN `guards_killed` INTEGER  NOT NULL DEFAULT 0 AFTER `last_raid_end`;

ALTER TABLE `Creature_Type` ADD COLUMN `image` VARCHAR(40)  AFTER `hire_cost`;

update Creature_Type set image = 'defaultportsmall.png';

update Creature_Type set image = 'ogremonsmall.png' where creature_type = 'Ogre';
update Creature_Type set image = 'goblinmonsmall.png' where creature_type = 'Goblin';
update Creature_Type set image = 'trollmonsmall.png' where creature_type = 'Troll';
update Creature_Type set image = 'skelmonsmall.png' where creature_type = 'Skelelton';
