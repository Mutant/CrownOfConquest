ALTER TABLE `Day` ADD COLUMN `turns_used` BIGINT  NOT NULL DEFAULT 0 AFTER `date_started`;

ALTER TABLE `Creature` ADD COLUMN `weapon` VARCHAR(255)  NOT NULL AFTER `group_order`;

UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Troll';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Goblin';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Orc Grunt';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Ogre';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Hobgoblin';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Centaur';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Satyr';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Cyclopse';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Dark Elf';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Minotaur';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Bugbear';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Skeleton';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Orc Lord';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Revenant';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Spectre';

UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Gorgon';
UPDATE `Creature_Type` set weapon = 'Razor Teeth' where creature_type = 'Manticore';
UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Chimera';
UPDATE `Creature_Type` set weapon = 'Death Gaze' where creature_type = 'Basilisk';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Werewolf';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Hell Hound';
UPDATE `Creature_Type` set weapon = 'Hypnotic Song' where creature_type = 'Harpy';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Gargoyle';
UPDATE `Creature_Type` set weapon = 'Freezing Touch' where creature_type = 'Wraith';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Zombie';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Ghoul';
UPDATE `Creature_Type` set weapon = 'Fire Blade' where creature_type = 'Lesser Demon';
UPDATE `Creature_Type` set weapon = 'Mesmeric Acid' where creature_type = 'Hypnotic Slime';
UPDATE `Creature_Type` set weapon = 'Puff of Smoke' where creature_type = 'Wisp';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Giant Wolf';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Succubus';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Iron Golem';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Clay Golem';
UPDATE `Creature_Type` set weapon = 'Melee Weapon' where creature_type = 'Stone Golem';
UPDATE `Creature_Type` set weapon = 'Indestructible Fire Blade' where creature_type = 'Demon Lord';
UPDATE `Creature_Type` set weapon = 'Enchanted Fire Blade' where creature_type = 'Greater Demon';
UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Fire Elemental';
UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Platinum Dragon';
UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Gold Dragon';
UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Silver Dragon';
UPDATE `Creature_Type` set weapon = 'Icy Breath' where creature_type = 'Ice Dragon';
UPDATE `Creature_Type` set weapon = 'Fire Breath' where creature_type = 'Fire Dragon';
UPDATE `Creature_Type` set weapon = 'Claws' where creature_type = 'Wyvern';

ALTER TABLE `Party_Town` ADD COLUMN `raids_today` INTEGER  NOT NULL DEFAULT 0 AFTER `tax_amount_paid_today`;

ALTER TABLE `Quest_Type` DROP COLUMN `xp_value`,
 DROP COLUMN `gold_value`,
 DROP COLUMN `min_level`;

ALTER TABLE `Quest_Type` ADD COLUMN `prevalence` INTEGER  NOT NULL DEFAULT 50 AFTER `hidden`;

UPDATE `Quest_Type` set prevalence = 100 where quest_type = 'msg_to_town';
UPDATE `Quest_Type` set prevalence = 100 where quest_type = 'kill_creatures_near_town';
UPDATE `Quest_Type` set prevalence = 80 where quest_type = 'find_jewel';
UPDATE `Quest_Type` set prevalence = 70 where quest_type = 'destroy_orb';

INSERT INTO `Quest_Type` (quest_type, hidden, prevalence) values ('raid_town', 0, 50);

INSERT INTO `Quest_Param_Name` (quest_param_name, quest_type_id) values ('Town To Raid', 5);
INSERT INTO `Quest_Param_Name` (quest_param_name, quest_type_id) values ('Raided Town', 5);

CREATE TABLE `Town_History` (
  `town_history_id` INTEGER  NOT NULL auto_increment,
  `message` VARCHAR(4000)  NOT NULL,
  `town_id` INTEGER  NOT NULL,
  `day_id` INTEGER  NOT NULL,
  `date_recorded` TIMESTAMP NOT NULL,
  PRIMARY KEY (`town_history_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Town_History` ADD INDEX `town_day_idx`(`town_id`, `day_id`);

ALTER TABLE `Party_Town` ADD COLUMN `prestige` INTEGER  NOT NULL DEFAULT 0 AFTER `raids_today`;