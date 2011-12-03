CREATE TABLE `Skill` (
  `skill_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `skill_name` VARCHAR(40)  NOT NULL,
  `type` VARCHAR(40)  NOT NULL,
  `description` VARCHAR(2000) NOT NULL,
  PRIMARY KEY (`skill_id`),
  INDEX `type_index`(`type`)
)
ENGINE = InnoDB;

CREATE TABLE `Character_Skill` (
  `character_id` INTEGER  NOT NULL,
  `skill_id` INTEGER  NOT NULL,
  `level` INTEGER  NOT NULL,
  PRIMARY KEY (`character_id`, `skill_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Character` ADD COLUMN `skill_points` INTEGER  NOT NULL DEFAULT 0;

UPDATE `Creature_Category` set name = 'Guard' where name = 'Guards';

INSERT INTO `Skill` VALUES (1,'Recall','','Allows spell casters a chance of recalling a spell immediately after casting it, meaning they don\'t use up a cast for the day'),(2,'Medicine','nightly','Allows the character a chance of healing their group\'s wounds over night'),(3,'Construction','','Gives the character a bonus when constructing buildings'),(4,'Fletching','nightly','Allows the character to produce ammunition for their equipped weapon each night'),(5,'Metallurgy','nightly','Gives the character the ability to repair minor damage to their weapons each night'),(6,'Tactics','','Allows character\'s party to prevent foes from fleeing. Also allows mayors to instruct their guards in offence'),(7,'Strategy','','Gives the character\'s group a greater chance of successfully fleeing from battles. Also allows mayors to instruct their guards in defence'),(8,'Charisma','','Mayors with good charisma will find it easier to gain approval, and win elections. Kings will gain greater popularity with the peasants in their realm'),(9,'Leadership','','Increases the amount of tax Mayors can collect from their towns. Increases the number of quests a King can assign.'),(10,'Berserker Rage','combat','Gives the character a chance of going into a Beserker rage during combat, increasing the damage they inflict'),(11,'War Cry','combat','Each round of combat, the character may sound a War Cry, giving them an increased chance of hitting their opponent'),(12,'Shield Bash','combat','Allows the character to bash their opponent with a shield, in addition to their normal attack for the round'),(13,'Eagle Eye','','Allows the character to spot weaknesses in their opponent\'s defence, giving them an increased chance of a critical hit'),(14,'Awareness','','Increases the character\'s chance of finding traps, secret doors, etc.'),(15,'Negotiation','','Reduces the cost of entry into towns. For mayors, improves their chances of defeating a revolt');

ALTER TABLE `Character_Skill` ADD INDEX `char_id`(`character_id`);

CREATE TABLE `Map_Tileset` (
  `tileset_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50)  NOT NULL,
  `prefix` VARCHAR(50)  NOT NULL,
  PRIMARY KEY (`tileset_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Land` ADD COLUMN `tileset_id` INTEGER  NOT NULL;

ALTER TABLE `Terrain` ADD COLUMN `image` VARCHAR(255)  NOT NULL AFTER `modifier`;
update Terrain set image = REPLACE(terrain_name, ' ', '_');
insert into `Terrain`(terrain_name, modifier, image) values ('chasm', '4', 'chasm');

INSERT INTO `Map_Tileset`(name, prefix) values ('Standard', '');
INSERT INTO `Map_Tileset`(name, prefix) values ('Snow', 'snow');
INSERT INTO `Map_Tileset`(name, prefix) values ('Snow Fading Bottom', 'snowfadingbottom');

UPDATE `Land` set tileset_id = 1;
UPDATE `Land` set tileset_id = 2 where y <= 20;
UPDATE `Land` set tileset_id = 3 where y = 21;

UPDATE `Land` set terrain_id = (select terrain_id from Terrain where terrain_name = 'chasm') where tileset_id = 2 and terrain_id = (select terrain_id from Terrain where terrain_name = 'marsh');

UPDATE `Land` set variation = 1 where tileset_id = 2 and terrain_id = (select terrain_id from Terrain where terrain_name = 'hill');
UPDATE `Land` set variation = 1 where tileset_id = 2 and terrain_id = (select terrain_id from Terrain where terrain_name = 'dense forest');
UPDATE `Land` set variation = 1 where tileset_id = 2 and terrain_id = (select terrain_id from Terrain where terrain_name = 'medium forest');
UPDATE `Land` set variation = 1 where tileset_id = 2 and terrain_id = (select terrain_id from Terrain where terrain_name = 'light forest');
UPDATE `Land` set variation = 1 where tileset_id = 2 and terrain_id = (select terrain_id from Terrain where terrain_name = 'mountain') and variation = 3;

UPDATE `Creature_Type` set hire_cost = 50 where creature_type = 'Seasoned Town Guard';
UPDATE `Creature_Type` set hire_cost = 100 where creature_type = 'Veteran Town Guard';
INSERT INTO `Creature_Type`(creature_type, level, weapon, fire, ice, poison, creature_category_id, hire_cost, image, special_damage)
	VALUES ('Elite Town Guard', 22, 'Melee Weapon', 65, 65, 65, (select creature_category_id from Creature_Category where name = 'Guard'), 400, 'veteranguard.png', 'Fire');

ALTER TABLE `Town` ADD COLUMN `trap_level` INTEGER  NOT NULL DEFAULT 0;

UPDATE `Item_Type` set weight = 10, base_cost = 70 where item_type = 'Iron';
UPDATE `Item_Type` set weight = 7, base_cost = 25 where item_type = 'Clay';
UPDATE `Item_Type` set weight = 6, base_cost = 12 where item_type = 'Wood';
UPDATE `Item_Type` set weight = 12, base_cost = 35 where item_type = 'Stone';

UPDATE `Building_Type` set defense_factor = 4 where name = 'Tower';
UPDATE `Building_Type` set defense_factor = 6 where name = 'Fort';
UPDATE `Building_Type` set defense_factor = 8 where name = 'Castle';

UPDATE `Creature_Type` set image = 'vampire.png' where creature_type = 'Vampire';
UPDATE `Creature_Type` set image = 'centaur.png' where creature_type = 'Centaur';
UPDATE `Creature_Type` set image = 'blacksorcerer.png' where creature_type = 'Black Sorcerer';
UPDATE `Creature_Type` set image = 'harpy.png' where creature_type = 'Harpy';


