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
INSERT INTO `Levels` VALUES (1,0),(2,250),(3,800),(4,1600),(5,2600),(6,3000),(7,4200),(8,6000),(9,8000),(10,10000),(11,12500),(12,14500),(13,18000),(14,23000),(15,29000),(16,35000),(17,41000),(18,48000),(19,55000),(20,62000),(21,70000),(22,79000),(23,89000),(24,100000),(25,112000);

CREATE TABLE `Dungeon_Special_Room` (
  `special_room_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `room_type` VARCHAR(200)  NOT NULL,
  PRIMARY KEY (`special_room_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Dungeon_Room` ADD COLUMN `special_room_id` INTEGER  AFTER `floor`;

CREATE TABLE `Dungeon_Room_Param` (
  `dungeon_room_param_id` BIGINT  NOT NULL AUTO_INCREMENT,
  `param_name` VARCHAR(100)  NOT NULL,
  `param_value` VARCHAR(200) ,
  PRIMARY KEY (`dungeon_room_param_id`)
)
ENGINE = InnoDB;

insert into Dungeon_Special_Room (room_type) values ('rare_monster');

ALTER TABLE `Creature_Type` ADD COLUMN `rare` TINYINT  NOT NULL DEFAULT 0 AFTER `image`;

INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Orc Shaman', 6, 'Golden Staff', 25, 25, 25, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Goblin Chief', 8, 'Melee Weapon', 28, 28, 28, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Bandit Leader', 14, 'Melee Weapon', 40, 40, 40, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Warlock', 12, 'Staff of Oden', 40, 40, 40, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Gelatinous Ooze', 16, 'Acidic Slime', 40, 40, 40, 1, (select creature_category_id from Creature_Category where name = 'Beast'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Black Sorcerer', 15, 'Mace of Death', 50, 50, 50, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Lich', 22, 'Melee Weapon', 65, 65, 65, 1, (select creature_category_id from Creature_Category where name = 'Undead'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Demon King', 24, 'Melee Weapon', 65, 65, 65, 1, (select creature_category_id from Creature_Category where name = 'Demon'));

INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Vampire', 19, 'Melee Weapon', 55, 55, 55, 0, (select creature_category_id from Creature_Category where name = 'Undead'));

UPDATE `Creature_Type` set portrait = 'defaultportsmall.png' where portrait is null;

CREATE TABLE `Creature_Spell` (
  `creature_spell_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `spell_id` INTEGER  NOT NULL,
  `creature_type_id` INTEGER  NOT NULL,
  PRIMARY KEY (`creature_spell_id`),
  INDEX `spell_idx`(`spell_id`),
  INDEX `type_id`(`creature_type_id`)
)
ENGINE = InnoDB;

