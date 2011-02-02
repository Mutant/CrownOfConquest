ALTER TABLE `Dungeon_Room` ADD COLUMN `floor` INTEGER  NOT NULL DEFAULT 1 AFTER `dungeon_id`;
ALTER TABLE `Dungeon_Grid` ADD COLUMN `stairs_down` TINYINT(4)  NOT NULL DEFAULT 0 AFTER `stairs_up`;

ALTER TABLE `Memorised_Spells` ADD INDEX `char_id`(`character_id`);

ALTER TABLE `Character` ADD COLUMN `attack_factor` INTEGER  NOT NULL DEFAULT 0 AFTER `has_usable_items`,
 ADD COLUMN `defence_factor` INTEGER  NOT NULL DEFAULT 0 AFTER `attack_factor`;

ALTER TABLE `Character` ADD COLUMN `back_rank_penalty` INTEGER  NOT NULL AFTER `defence_factor`;

ALTER TABLE `Dungeon_Grid` ADD COLUMN `tile` TINYINT  NOT NULL DEFAULT 1 AFTER `stairs_down`,
 ADD COLUMN `overlay` VARCHAR(200)  DEFAULT NULL AFTER `tile`;

ALTER TABLE `Dungeon` ADD COLUMN `tileset` VARCHAR(50)  DEFAULT NULL AFTER `type`;


DELETE FROM `Levels`;
INSERT INTO `Levels` VALUES (1,0),(2,200),(3,450),(4,900),(5,1400),(6,2000),(7,2600),(8,3300),(9,4000),(10,5000),(11,10000),(12,13000),(13,18000),(14,23000),(15,29000),(16,35000),(17,42000),(18,49000),(19,55000),(20,60000);


