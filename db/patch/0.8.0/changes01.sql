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

