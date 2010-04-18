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
ALTER TABLE `Player` ADD COLUMN `display_announcements` TINYINT(1) NOT NULL DEFAULT 1 AFTER `warned_for_deletion`;
ALTER TABLE `Player` ADD COLUMN `display_tip_of_the_day` TINYINT(1) NOT NULL DEFAULT 1 AFTER `warned_for_deletion`;
ALTER TABLE `Player` ADD COLUMN `send_email` TINYINT(1) NOT NULL DEFAULT 1 AFTER `warned_for_deletion`;

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

CREATE TABLE `Announcement` (
  `announcement_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(255) NOT NULL,
  `announcement` TEXT NOT NULL,
  `date` DATETIME NOT NULL,
  PRIMARY KEY (`announcement_id`)
)
ENGINE = InnoDB;

CREATE TABLE `Announcement_Player` (
  `announcement_id` INTEGER  NOT NULL,
  `player_id` INTEGER  NOT NULL,
  `viewed` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`announcement_id`,`player_id`)
)
ENGINE = InnoDB;

alter table Party add INDEX dungeon_idx(dungeon_grid_id);

alter table `Character` add INDEX party_id_idx(party_id);

CREATE TABLE `Tip` (
  `tip_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(255) NOT NULL,
  `tip` TEXT NOT NULL,
  PRIMARY KEY (`tip_id`)
)
ENGINE = InnoDB;

INSERT INTO `Tip` VALUES (1,'Find the best shops','Towns with higher prosperity tend to have better shops. Here, you\'ll find a bigger range at cheaper prices. Certain shops within each town will be even better. Make a note of the best ones, and check back often'),(2,'','Increasing your prestige rating with a town can net your party a discount at certain services in the town'),(3,'A good Blacksmith is hard to find','The skill of a town\'s blacksmith increases over time. Check the blacksmith\'s description to see how long he\'s been around'),(4,'','Upgrading your weapons and armour at the blacksmith is an excellent way of getting the most out of your equipment'),(5,'','Quests are an excellent way for new parties to increase their wealth and experience. To start a quest, head to the Town Hall of the nearest town'),(6,'Multi-tasking','You can only get one quest from each town at a time, but there\'s nothing stopping you having several quests from different towns. The maximum quests you can have at a time is determined by your party\'s level. Just make sure you have enough time to complete them all, or the town\'s council won\'t be happy!'),(7,'Finding a quest','The bigger the town (i.e. the higher it\'s prosperity) the more likely it is to have a big selection of quests. Not all quests will be offered to you though - some depend on your party level.'),(8,'Dungeons','Once you\'ve slaughtered a few easy monsters in the wilderness, and got a few easy quests under your belt, it\'s a good idea to head to a dungeon, where you\'ll find a lot of creatures, treasure and more. If you need to find a dungeon in your area, head to the Sage. The dungeons you know about are listed on the \'Map\' screen.'),(9,'Turns','You don\'t need to log into Kingdoms every day to make use of all your turns. Turns will accumulate for a few days, before you have to use them or lose them.'),(10,'The Watcher','New parties start with a \'Watcher\' effect, a force that gives you an indication of how tough each group of monsters is. This effect lasts for 20 days - if you need more, one of your mages will have to cast a \'Watcher\' spell.'),(11,'Prosperity','A town\'s prosperity is an indication of how big it is, and how likely it is to have a good range of services at good prices. A number of factors influence a town\'s prosperity. For instance, if a town collects a good amount of tax, and keeps the surrounding wildnerness clear of monsters, it\'s prosperity will likely go up. Your party can nurture a town\'s prosperity, and reap the benefits as its services improve.');


CREATE TABLE `Dungeon_Sector_Path` (
  `sector_id` INTEGER  NOT NULL,
  `has_path_to` INTEGER  NOT NULL,
  `distance` INTEGER NOT NULL,
  PRIMARY KEY (`sector_id`, `has_path_to`)
)
ENGINE = InnoDB;

CREATE TABLE `Dungeon_Sector_Path_Door` (
  `sector_id` INTEGER  NOT NULL,
  `has_path_to` INTEGER  NOT NULL,
  `door_id` INTEGER NOT NULL,
  PRIMARY KEY (`sector_id`, `has_path_to`, `door_id`)
)
ENGINE = InnoDB;

