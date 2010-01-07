CREATE TABLE `Road` (
  `road_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `position` VARCHAR(40)  NOT NULL,
  `land_id` INTEGER  NOT NULL,
  PRIMARY KEY (`road_id`),
  INDEX `land_id_idx`(`land_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Player` ADD COLUMN `send_daily_report` TINYINT(1) NOT NULL DEFAULT 1 AFTER `warned_for_deletion`;

UPDATE `Quest` SET min_level = 8 WHERE quest_type_id = 5; 

CREATE TABLE `Treasure_Chest` (
  `treasure_chest_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `dungeon_grid_id` INTEGER  NOT NULL,
  PRIMARY KEY (`treasure_chest_id`),
  INDEX `grid_id_idx`(`dungeon_grid_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Items` ADD COLUMN `treasure_chest_id` INTEGER NULL AFTER `shop_id`;

ALTER TABLE `Treasure_Chest` ADD COLUMN `trap` VARCHAR(255) NULL AFTER `dungeon_grid_id`;