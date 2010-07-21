ALTER TABLE `Quest` ADD COLUMN `days_to_complete` INTEGER  NOT NULL DEFAULT 0 AFTER `status`;

DELETE FROM `Quest` WHERE party_id is null AND status = 'Not Started' and days_to_complete = 0;

CREATE TABLE `Party_Town` (
    party_id       INT NOT NULL,
    town_id        INT NOT NULL,
    tax_amount_paid_today INT NOT NULL DEFAULT 0,
PRIMARY KEY (party_id,town_id)) TYPE=INNODB;

CREATE TABLE `Party_Battle` (
    battle_id      INT NOT NULL AUTO_INCREMENT,
PRIMARY KEY (battle_id)) TYPE=INNODB;

CREATE TABLE `Battle_Participant` (
    party_id       INT NOT NULL,
    battle_id      INT NOT NULL,
    last_submitted_round INT NOT NULL,
    online  TINYINT NOT NULL DEFAULT 0,
PRIMARY KEY (party_id,battle_id)) TYPE=INNODB;

ALTER TABLE `Character` ADD COLUMN `last_combat_param1` VARCHAR(255)  NOT NULL AFTER `town_id`,
 ADD COLUMN `last_combat_param2` VARCHAR(255)  NOT NULL AFTER `last_combat_param1`;

ALTER TABLE `Combat_Log` CHANGE COLUMN `party_id` `opponent_1_id` INTEGER  NOT NULL,
 CHANGE COLUMN `creature_group_id` `opponent_2_id` INTEGER  NOT NULL,
 ADD COLUMN `opponent_1_type` VARCHAR(50)  NOT NULL DEFAULT 'party' AFTER `flee_attempts`,
 ADD COLUMN `opponent_2_type` VARCHAR(50)  NOT NULL DEFAULT 'creature_group' AFTER `opponent_1_type`,
 ADD COLUMN `session` TEXT  DEFAULT NULL AFTER `opponent_2_type`;
 
ALTER TABLE `Party` ADD COLUMN `flee_threshold` INTEGER  NOT NULL DEFAULT 70 AFTER `dungeon_grid_id`;

ALTER TABLE `Combat_Log` CHANGE COLUMN `creature_deaths` `opponent_2_deaths` INTEGER  NOT NULL DEFAULT 0,
 CHANGE COLUMN `character_deaths` `opponent_1_deaths` INTEGER  NOT NULL DEFAULT 0,
 CHANGE COLUMN `total_creature_damage` `total_opponent_2_damage` INTEGER  NOT NULL DEFAULT 0,
 CHANGE COLUMN `total_character_damage` `total_opponent_1_damage` INTEGER  NOT NULL DEFAULT 0,
 CHANGE COLUMN `party_level` `opponent_1_level` INTEGER  NOT NULL DEFAULT 0,
 CHANGE COLUMN `creature_group_level` `opponent_2_level` INTEGER  NOT NULL DEFAULT 0,
 CHANGE COLUMN `flee_attempts` `opponent_1_flee_attempts` INTEGER  DEFAULT NULL,
 ADD COLUMN `opponent_2_flee_attempts` INTEGER  DEFAULT NULL AFTER `game_day`;

ALTER TABLE `Party` DROP COLUMN `new_day_due`;

UPDATE `Combat_Log` SET combat_initiated_by = 'opp1' where combat_initiated_by = 'party';
UPDATE `Combat_Log` SET combat_initiated_by = 'opp2' where combat_initiated_by = 'creatures';

UPDATE `Item_Type` SET image = '26-steelheadcap.PNG' where item_type_id = 26;
UPDATE `Item_Type` SET image = '32-broadsword.PNG' where item_type_id = 32;
UPDATE `Item_Type` SET image = '35-scalemail.PNG' where item_type_id = 35;
UPDATE `Item_Type` SET image = '36-fullplatemail.PNG' where item_type_id = 36;
UPDATE `Item_Type` SET image = '37-mediumsteelshield.PNG' where item_type_id = 37;
UPDATE `Item_Type` SET image = '38-largesteelshield.PNG' where item_type_id = 38;
UPDATE `Item_Type` SET image = '39-smallsteelshield.PNG' where item_type_id = 39;
 