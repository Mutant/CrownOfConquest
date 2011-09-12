ALTER TABLE `Kingdom` ADD COLUMN `capital` INTEGER DEFAULT NULL,
 ADD INDEX `capital_idx`(`capital`);

CREATE TABLE  `Capital_History` (
  `capital_id` int(11) NOT NULL AUTO_INCREMENT,  
  `kingdom_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `start_date` int(11) NOT NULL,
  `end_date` int(11) DEFAULT NULL,
    PRIMARY KEY (`capital_id`) USING BTREE,
  KEY `kingdom_id_idx` (`kingdom_id`)
) ENGINE=InnoDB;

CREATE TABLE `Kingdom_Town` (
  `kingdom_id` INTEGER  NOT NULL,
  `town_id` INTEGER  NOT NULL,
  `loyalty` INTEGER  NOT NULL DEFAULT 0,
  PRIMARY KEY (`kingdom_id`, `town_id`)
)
ENGINE = InnoDB;


ALTER TABLE `Item_Category` ADD COLUMN `delete_when_sold_to_shop` TINYINT(4)  NOT NULL DEFAULT 0;
UPDATE `Item_Category` SET delete_when_sold_to_shop = 1 where item_category = 'Jewel' or item_category = 'Special Items';
UPDATE `Item_Category` SET findable = 0, auto_add_to_shop = 1 where item_category = 'Jewel';

ALTER TABLE `Creature_Category` ADD COLUMN `dungeon_group_img` VARCHAR(50);
INSERT INTO `Creature_Category` (name, dungeon_group_img) VALUES ('Rodent', 'rodent');
INSERT INTO `Creature_Type` (creature_type, level, weapon, fire, ice, poison, creature_category_id, image)
	VALUES ('Rat', 1, 'Claws', 3, 3, 3, (select creature_category_id from Creature_Category where name = 'Rodent'), 'defaultport.png');
INSERT INTO `Creature_Type` (creature_type, level, weapon, fire, ice, poison, creature_category_id, image)
	VALUES ('Weasel', 1, 'Claws', 3, 3, 3, (select creature_category_id from Creature_Category where name = 'Rodent'), 'defaultport.png');
INSERT INTO `Creature_Type` (creature_type, level, weapon, fire, ice, poison, creature_category_id, image)
	VALUES ('Ferret', 1, 'Claws', 3, 3, 3, (select creature_category_id from Creature_Category where name = 'Rodent'), 'defaultport.png');

ALTER TABLE `Creature_Category` ADD COLUMN `standard` TINYINT  NOT NULL DEFAULT 1;
UPDATE `Creature_Category` set standard = 0 where name = 'Guards' or name = 'Rodent';

