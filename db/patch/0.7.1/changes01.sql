ALTER TABLE `Dungeon_Room` ADD COLUMN `floor` INTEGER  NOT NULL DEFAULT 1 AFTER `dungeon_id`;
ALTER TABLE `Dungeon_Grid` ADD COLUMN `stairs_down` TINYINT(4)  NOT NULL DEFAULT 0 AFTER `stairs_up`;


