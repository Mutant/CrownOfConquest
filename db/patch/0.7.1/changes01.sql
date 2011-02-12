ALTER TABLE `Dungeon_Room` ADD COLUMN `floor` INTEGER  NOT NULL DEFAULT 1 AFTER `dungeon_id`;
ALTER TABLE `Dungeon_Grid` ADD COLUMN `stairs_down` TINYINT(4)  NOT NULL DEFAULT 0 AFTER `stairs_up`;

ALTER TABLE `Memorised_Spells` ADD INDEX `char_id`(`character_id`);

ALTER TABLE `Character` ADD COLUMN `attack_factor` INTEGER  NOT NULL DEFAULT 0 AFTER `movement_factor_bonus`,
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
ALTER TABLE `Creature_Type` ADD COLUMN `special_damage` VARCHAR(40)  AFTER `rare`;

INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Orc Shaman', 6, 'Golden Staff', 25, 25, 25, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Goblin Chief', 8, 'Melee Weapon', 28, 28, 28, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, special_damage, creature_category_id)
	VALUES ('Bandit Leader', 14, 'Melee Weapon', 40, 40, 40, 1, 'Ice', (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Warlock', 12, 'Staff of Oden', 40, 40, 40, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, special_damage, creature_category_id)
	VALUES ('Gelatinous Ooze', 16, 'Acidic Slime', 40, 40, 40, 1, 'Poison', (select creature_category_id from Creature_Category where name = 'Beast'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Black Sorcerer', 15, 'Mace of Death', 50, 50, 50, 1, (select creature_category_id from Creature_Category where name = 'Humanoid'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Lich', 22, 'Melee Weapon', 65, 65, 65, 1, (select creature_category_id from Creature_Category where name = 'Undead'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, special_damage, creature_category_id)
	VALUES ('Demon King', 24, 'Melee Weapon', 65, 65, 80, 1, 'Fire', (select creature_category_id from Creature_Category where name = 'Demon'));

INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Vampire', 19, 'Melee Weapon', 55, 55, 55, 0, (select creature_category_id from Creature_Category where name = 'Undead'));
INSERT into `Creature_Type` (creature_type, level, weapon, fire, ice, poison, rare, creature_category_id)
	VALUES ('Devil\'s Spawn', 20, 'Melee Weapon', 50, 50, 50, 0, (select creature_category_id from Creature_Category where name = 'Demon'));


UPDATE `Creature_Type` set image = 'defaultportsmall.png' where image is null;

CREATE TABLE `Creature_Spell` (
  `creature_spell_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `spell_id` INTEGER  NOT NULL,
  `creature_type_id` INTEGER  NOT NULL,
  PRIMARY KEY (`creature_spell_id`),
  INDEX `spell_idx`(`spell_id`),
  INDEX `type_id`(`creature_type_id`)
)
ENGINE = InnoDB;


DROP TABLE IF EXISTS `Building`;
CREATE TABLE `Building` (
  `building_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `land_id` INTEGER  NOT NULL,
  `building_type_id` INTEGER NOT NULL,
  `owner_id` INTEGER NOT NULL,
  `owner_type` VARCHAR(20),
  `name` VARCHAR(100),
  `clay_needed` INTEGER,
  `stone_needed` INTEGER DEFAULT 0,
  `wood_needed` INTEGER DEFAULT 0,
  `iron_needed` INTEGER DEFAULT 0,
  `labor_needed` INTEGER DEFAULT 0,
  PRIMARY KEY (`building_id`)
)
ENGINE = InnoDB;

DROP TABLE IF EXISTS `Building_Type`;
CREATE TABLE `Building_Type` (
  `building_type_id` INTEGER NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100),
  `class` INTEGER DEFAULT 0,
  `level` INTEGER DEFAULT 0,
  `defense_factor` INTEGER DEFAULT 0,
  `attack_factor` INTEGER DEFAULT 0,
  `heal_factor` INTEGER DEFAULT 0,
  `commerce_factor` INTEGER DEFAULT 0,
  `clay_needed` INTEGER,
  `stone_needed` INTEGER,
  `wood_needed` INTEGER,
  `iron_needed` INTEGER,
  `labor_needed` INTEGER,
  `labor_to_raze` INTEGER,
  `image` VARCHAR(255) NOT NULL,
  `constr_image` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`building_type_id`)
)
ENGINE = InnoDB;

INSERT INTO Building_Type
 (name, class, level, defense_factor, attack_factor, heal_factor, commerce_factor,
  clay_needed, stone_needed, wood_needed, iron_needed, labor_needed, labor_to_raze,
  image, constr_image) VALUES
 ('Tower', 1, 1, 2, 2, 2, 1, 0, 10, 5, 3, 10, 10, 'fortfin.png', 'fortinprog.png');
INSERT INTO Building_Type
 (name, class, level, defense_factor, attack_factor, heal_factor, commerce_factor,
  clay_needed, stone_needed, wood_needed, iron_needed, labor_needed, labor_to_raze,
  image, constr_image) VALUES
 ('Fort', 1, 2, 4, 4, 4, 2, 0, 20, 10, 5, 20, 20, 'fortfin.png', 'fortinprog.png');
INSERT INTO Building_Type
 (name, class, level, defense_factor, attack_factor, heal_factor, commerce_factor,
  clay_needed, stone_needed, wood_needed, iron_needed, labor_needed, labor_to_raze,
  image, constr_image) VALUES
 ('Castle', 1, 3, 8, 8, 8, 4, 0, 40, 20, 10, 40, 40, 'fortfin.png', 'fortinprog.png');


DELETE FROM Item_Type WHERE item_category_id in
 (select item_category_id from Item_Category where Item_category in ('Tool', 'Resource'));
ALTER TABLE Item_Type AUTO_INCREMENT = 50;

DELETE FROM Item_Category where Item_category in ('Resource', 'Tool');
ALTER TABLE Item_Category AUTO_INCREMENT = 10;

INSERT INTO Item_Category
 (Item_category, hidden, auto_add_to_shop, findable)
 VALUES ('Resource', 0, 1, 0);
DELETE FROM Item_Variable_Name WHERE item_category_id in
 (select item_category_id from Item_Category where Item_category = 'Resource');
INSERT INTO Item_Variable_Name (item_variable_name, create_on_insert, item_category_id)
 VALUES ('Quantity', 1,
 (select item_category_id from Item_Category where Item_category = 'Resource'));


INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Iron', 100, 100, 10, 'iron.png',
 (select item_category_id from Item_Category where Item_category = 'Resource'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Iron';

INSERT INTO Item_Variable_Params (keep_max,min_value,max_value,item_type_id,item_variable_name_id)
 VALUES (0, 1, 50, (select item_type_id from Item_Type where Item_Type = 'Iron'),
 (select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Quantity' and
 item_category_id = (select item_category_id from Item_Category where Item_category = 'Resource')));


INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Clay', 50, 100, 5, 'clay.png',
 (select item_category_id from Item_Category where Item_category = 'Resource'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Clay';

INSERT INTO Item_Variable_Params (keep_max,min_value,max_value,item_type_id,item_variable_name_id)
 VALUES (0, 1, 50, (select item_type_id from Item_Type where Item_Type = 'Clay'),
 (select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Quantity' and
 item_category_id = (select item_category_id from Item_Category where Item_category = 'Resource')));


INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Wood', 30, 100, 4, 'wood.png',
 (select item_category_id from Item_Category where Item_category = 'Resource'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Wood';

INSERT INTO Item_Variable_Params (keep_max,min_value,max_value,item_type_id,item_variable_name_id)
 VALUES (0, 1, 50, (select item_type_id from Item_Type where Item_Type = 'Wood'),
 (select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Quantity' and
 item_category_id = (select item_category_id from Item_Category where Item_category = 'Resource')));


INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Stone', 40, 100, 10, 'stone.png',
 (select item_category_id from Item_Category where Item_category = 'Resource'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Stone';

INSERT INTO Item_Variable_Params (keep_max,min_value,max_value,item_type_id,item_variable_name_id)
 VALUES (0, 1, 50, (select item_type_id from Item_Type where Item_Type = 'Stone'),
 (select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Quantity' and
 item_category_id = (select item_category_id from Item_Category where item_category = 'Resource')));


INSERT INTO Item_Category
 (Item_category, hidden, auto_add_to_shop, findable)
 VALUES ('Tool', 1, 1, 0);

INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Mallet', 50, 100, 15, 'mallet.png',
 (select item_category_id from Item_Category where Item_category = 'Tool'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Mallet';

INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Hammer', 70, 100, 10, 'hammer.png',
 (select item_category_id from Item_Category where Item_category = 'Tool'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Hammer';

INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Pickaxe', 40, 100, 25, 'pickaxe.png',
 (select item_category_id from Item_Category where Item_category = 'Tool'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Pickaxe';

INSERT INTO `Item_Type`(Item_Type, base_cost, prevalence, weight, image, item_category_id)
 VALUES ('Shovel', 30, 100, 20, 'shovel.png',
 (select item_category_id from Item_Category where Item_category = 'Tool'));

update Item_Type set image = concat(item_type_id, '-', image) where Item_Type = 'Shovel';

