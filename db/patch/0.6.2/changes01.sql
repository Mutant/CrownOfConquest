CREATE  TABLE IF NOT EXISTS `Enchantments` (
  `enchantment_id` INT NOT NULL AUTO_INCREMENT ,
  `enchantment_name` VARCHAR(100) NOT NULL ,
  `must_be_equipped` TINYINT NOT NULL DEFAULT '0',
  PRIMARY KEY (`enchantment_id`) )
ENGINE = InnoDB;

CREATE  TABLE IF NOT EXISTS `Item_Enchantments` (
  `item_enchantment_id` INT NOT NULL AUTO_INCREMENT ,
  `enchantment_id` INT NOT NULL ,
  `item_id` INT(11) NOT NULL ,
  PRIMARY KEY (`item_enchantment_id`) ,
  INDEX `fk_Enchantments_has_Items_Enchantments1` (`enchantment_id` ASC) ,
  INDEX `fk_Enchantments_has_Items_Items1` (`item_id` ASC) )
ENGINE = InnoDB;

ALTER TABLE `Item_Variable` MODIFY COLUMN `item_variable_name_id` INTEGER  DEFAULT NULL,
 ADD COLUMN `item_enchantment_id` INTEGER  AFTER `item_variable_name_id`,
 ADD COLUMN `name` VARCHAR(100)  AFTER `item_enchantment_id`;
ALTER TABLE `Item_Variable` MODIFY COLUMN `item_variable_value` VARCHAR(100)  NOT NULL;

ALTER TABLE `Enchantments` ADD COLUMN `one_per_item` TINYINT(4)  NOT NULL DEFAULT 0 AFTER `must_be_equipped`;

INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('spell_casts_per_day',0);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('indestructible',1);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('magical_damage',1);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('daily_heal',1);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('extra_turns',1);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('bonus_against_creature_category',0);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('stat_bonus',0);

CREATE  TABLE IF NOT EXISTS `Enchantment_Item_Category` (
  `enchantment_id` INT NOT NULL,
  `item_category_id` INT NOT NULL,
  PRIMARY KEY (`enchantment_id`,`item_category_id`) )
ENGINE = InnoDB;

ALTER TABLE `Creature_Type` ADD COLUMN `fire` INT  NOT NULL AFTER `weapon`,
 ADD COLUMN `ice` INT  NOT NULL AFTER `fire`,
 ADD COLUMN `poison` INT  NOT NULL AFTER `ice`;

UPDATE `Creature_Type` SET fire = level * 3, ice = level * 3, poison = level * 3;

CREATE TABLE `Creature_Category` (
  `creature_category_id` INT  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255)  NOT NULL,
  PRIMARY KEY (`creature_category_id`)
)
ENGINE = InnoDB;

INSERT INTO `Creature_Category` VALUES (1,'Beast'),(2,'Demon'),(3,'Golem'),(4,'Dragon'),(5,'Undead'),(6,'Humanoid'),(7,'Lycanthrope');

ALTER TABLE `Creature_Type` ADD COLUMN `creature_category_id` INTEGER  NOT NULL AFTER `poison`,
 ADD INDEX `category_fk`(`creature_category_id`);

UPDATE `Creature_Type` set creature_category_id = 6
	where creature_type = 'Troll' or creature_type = "Goblin" or creature_type = "Orc Grunt" or creature_type = "Ogre" or creature_type = "Hobgoblin" or creature_type = "Centaur" or creature_type =   
        "Satyr" or creature_type = "Dark Elf" or creature_type = "Minotaur" or creature_type = "Harpy" or creature_type = "Bugbear" or creature_type = "Gargoyle" or creature_type = "Orc Lord";

UPDATE `Creature_Type` set creature_category_id = 5
	where creature_type = "Wraith" or creature_type = "Spectre" or creature_type = "Skeleton" or creature_type = "Zombie" or creature_type = "Ghoul" or creature_type = "Revenant";

UPDATE `Creature_Type` set creature_category_id = 4
	where creature_type = "Ice Dragon" or creature_type = "Platinum Dragon" or creature_type = "Gold Dragon" or creature_type = "Silver Dragon" or creature_type = "Fire Dragon";

UPDATE `Creature_Type` set creature_category_id = 3
	where creature_type = "Iron Golem" or creature_type = "Clay Golem" or creature_type = "Stone Golem";

UPDATE `Creature_Type` set creature_category_id = 2
	where creature_type = "Demon Lord" or creature_type = "Greater Demon" or creature_type = "Lesser Demon";

INSERT INTO `Creature_Type`(creature_type, level, weapon, fire, ice, poison, creature_category_id) values ('Wererat', 5, 'Claws', 15, 15, 15, 7);
INSERT INTO `Creature_Type`(creature_type, level, weapon, fire, ice, poison, creature_category_id) values ('Werebear', 9, 'Claws', 27, 27, 27, 7);
INSERT INTO `Creature_Type`(creature_type, level, weapon, fire, ice, poison, creature_category_id) values ('Weretiger', 11, 'Claws', 33, 33, 33, 7);

UPDATE `Creature_Type` set creature_category_id = 7
	where creature_type = 'Werewolf';

UPDATE `Creature_Type` set creature_category_id = 1 where creature_category_id = 0 or creature_category_id is null;
