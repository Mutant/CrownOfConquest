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

INSERT INTO `Quest_Type`(quest_type, hidden, prevalence) VALUES ('find_dungeon_item', 0, 40);

INSERT INTO `Quest_Param_Name`(quest_param_name, quest_type_id) VALUES('Item', (select quest_type_id FROM `Quest_Type` where quest_type = 'find_dungeon_item'));
INSERT INTO `Quest_Param_Name`(quest_param_name, quest_type_id) VALUES('Dungeon', (select quest_type_id FROM `Quest_Type` where quest_type = 'find_dungeon_item'));
INSERT INTO `Quest_Param_Name`(quest_param_name, quest_type_id) VALUES('Item Found', (select quest_type_id FROM `Quest_Type` where quest_type = 'find_dungeon_item'));

INSERT INTO `Item_Category`(item_category, hidden, auto_add_to_shop) VALUES ('Special Items', 0, 0);

INSERT INTO `Item_Type`(item_type, item_category_id) VALUES 
	('Artifact', (select item_category_id from Item_Category where item_category = 'Special Items'));

ALTER TABLE `Item_Type` ADD COLUMN `weight` DECIMAL(10,2) NOT NULL AFTER `prevalence`;

UPDATE `Item_Type` SET weight = 10 WHERE item_type = 'Short Sword';
UPDATE `Item_Type` SET weight = 25 WHERE item_type = 'Long Sword';
UPDATE `Item_Type` SET weight = 33 WHERE item_type = 'Leather Armour';
UPDATE `Item_Type` SET weight = 56 WHERE item_type = 'Chain Mail';
UPDATE `Item_Type` SET weight = 0.1 WHERE item_type = 'Arrows';
UPDATE `Item_Type` SET weight = 12 WHERE item_type = 'Short Bow';
UPDATE `Item_Type` SET weight = 36 WHERE item_type = 'Battle Axe';
UPDATE `Item_Type` SET weight = 8 WHERE item_type = 'Head Scarf';
UPDATE `Item_Type` SET weight = 14 WHERE item_type = 'Leather Helmet';
UPDATE `Item_Type` SET weight = 7 WHERE item_type = 'Dagger';
UPDATE `Item_Type` SET weight = 5 WHERE item_type = 'Sling';
UPDATE `Item_Type` SET weight = 0.2 WHERE item_type = 'Sling Stones';
UPDATE `Item_Type` SET weight = 13 WHERE item_type = 'Wooden Shield';
UPDATE `Item_Type` SET weight = 19 WHERE item_type = 'Large Wooden Shield';
UPDATE `Item_Type` SET weight = 19 WHERE item_type = 'Bronze Head Cap';
UPDATE `Item_Type` SET weight = 34 WHERE item_type = 'Two-Handed Sword';
UPDATE `Item_Type` SET weight = 18 WHERE item_type = 'Hand Axe';
UPDATE `Item_Type` SET weight = 15 WHERE item_type = 'Small Crossbow';
UPDATE `Item_Type` SET weight = 0.1 WHERE item_type = 'Crossbow Bolt';
UPDATE `Item_Type` SET weight = 23 WHERE item_type = 'Bastard Sword';
UPDATE `Item_Type` SET weight = 20 WHERE item_type = 'Spear';
UPDATE `Item_Type` SET weight = 63 WHERE item_type = 'Splint Mail';
UPDATE `Item_Type` SET weight = 26 WHERE item_type = 'Steel Head Cap';
UPDATE `Item_Type` SET weight = 32 WHERE item_type = 'Flail';
UPDATE `Item_Type` SET weight = 29 WHERE item_type = 'Mace';
UPDATE `Item_Type` SET weight = 29 WHERE item_type = 'Pike';
UPDATE `Item_Type` SET weight = 18 WHERE item_type = 'Quarterstaff';
UPDATE `Item_Type` SET weight = 38 WHERE item_type = 'Halberd';
UPDATE `Item_Type` SET weight = 27 WHERE item_type = 'Broadsword';
UPDATE `Item_Type` SET weight = 27 WHERE item_type = 'War Hammer';
UPDATE `Item_Type` SET weight = 16 WHERE item_type = 'Long Bow';
UPDATE `Item_Type` SET weight = 72 WHERE item_type = 'Scale Mail';
UPDATE `Item_Type` SET weight = 103 WHERE item_type = 'Full Plate Mail';
UPDATE `Item_Type` SET weight = 26 WHERE item_type = 'Medium Steel Shield';
UPDATE `Item_Type` SET weight = 34 WHERE item_type = 'Large Steel Shield';
UPDATE `Item_Type` SET weight = 21 WHERE item_type = 'Small Steel Shield';

UPDATE `Item_Type` SET weight = 1 WHERE weight = 0;

ALTER TABLE `Player` ADD COLUMN `send_email_announcements` TINYINT(1) NOT NULL DEFAULT 1 AFTER `warned_for_deletion`;

CREATE TABLE `Survey_Response` (
  `survey_response_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `reason` VARCHAR(255),
  `favourite` VARCHAR(255),
  `least_favourite` VARCHAR(255),
  `feedback` VARCHAR(2000),
  `email` VARCHAR(255),
  `added` TIMESTAMP,
  `party_level` INT,
  `turns_used` INT,
  PRIMARY KEY (`survey_response_id`)
)
ENGINE = InnoDB;
