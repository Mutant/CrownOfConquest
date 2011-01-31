ALTER TABLE `Dungeon_Room` ADD COLUMN `floor` INTEGER  NOT NULL DEFAULT 1 AFTER `dungeon_id`;
ALTER TABLE `Dungeon_Grid` ADD COLUMN `stairs_down` TINYINT(4)  NOT NULL DEFAULT 0 AFTER `stairs_up`;

ALTER TABLE `Memorised_Spells` ADD INDEX `char_id`(`character_id`);

ALTER TABLE `Character` ADD COLUMN `attack_factor` INTEGER  NOT NULL DEFAULT 0 AFTER `has_usable_items`,
 ADD COLUMN `defence_factor` INTEGER  NOT NULL DEFAULT 0 AFTER `attack_factor`;

ALTER TABLE `Character` ADD COLUMN `back_rank_penalty` INTEGER  NOT NULL AFTER `defence_factor`;




