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
PRIMARY KEY (party_id,battle_id)) TYPE=INNODB;

ALTER TABLE `Character` ADD COLUMN `last_combat_param1` VARCHAR(255)  NOT NULL AFTER `town_id`,
 ADD COLUMN `last_combat_param2` VARCHAR(255)  NOT NULL AFTER `last_combat_param1`;

ALTER TABLE `Combat_Log` CHANGE COLUMN `party_id` `opponent_1_id` INTEGER  NOT NULL,
 CHANGE COLUMN `creature_group_id` `opponent_2_id` INTEGER  NOT NULL,
 ADD COLUMN `opponent_1_type` VARCHAR(50)  NOT NULL DEFAULT 'party' AFTER `flee_attempts`,
 ADD COLUMN `opponent_2_type` VARCHAR(50)  NOT NULL DEFAULT 'creature_group' AFTER `opponent_1_type`,
 ADD COLUMN `session` TEXT  DEFAULT NULL AFTER `opponent_2_type`;
 