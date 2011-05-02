CREATE TABLE `Kingdom` (
  `kingdom_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255)  NOT NULL,
  `colour` VARCHAR(255)  NOT NULL,
  `mayor_tax` INTEGER NOT NULL DEFAULT 10,
  `gold` INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (`kingdom_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Land` ADD COLUMN `kingdom_id` INTEGER  AFTER `creature_threat`,
 ADD INDEX `kingdom_idx`(`kingdom_id`);

ALTER TABLE `Quest` MODIFY COLUMN `town_id` INTEGER  DEFAULT NULL,
 ADD COLUMN `kingdom_id` INTEGER  DEFAULT NULL AFTER `town_id`,
 ADD INDEX `party_id_idx`(`party_id`),
 ADD INDEX `town_id_idx`(`town_id`),
 ADD INDEX `kingdom_id_idx`(`kingdom_id`);

ALTER TABLE `Quest_Type` ADD COLUMN `description` VARCHAR(255);

ALTER TABLE `Quest_Type` ADD COLUMN `owner_type` VARCHAR(40)  NOT NULL DEFAULT 'town' AFTER `prevalence`;

INSERT INTO `Quest_Type`(quest_type, owner_type, description) values ('construct_building', 'kingdom', 'Construct A Building');

set @construct_building_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'construct_building');

INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@construct_building_id, 'Building Location');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@construct_building_id, 'Building Type');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@construct_building_id, 'Built');

INSERT INTO `Quest_Type`(quest_type, owner_type, description) values ('claim_land', 'kingdom', 'Claim Land');
set @claim_land_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'claim_land');

INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@claim_land_id, 'Amount To Claim');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@claim_land_id, 'Amount Claimed');

ALTER TABLE `Party` ADD COLUMN `kingdom_id` INTEGER  DEFAULT NULL AFTER `combat_type`,
 ADD INDEX `kingdom_id_idx`(`kingdom_id`),
 ADD INDEX `player_id_idx`(`player_id`);

ALTER TABLE `Building_Type` ADD COLUMN `land_claim_range` INTEGER  NOT NULL DEFAULT 1 AFTER `constr_image`;

update `Building_Type` set land_claim_range = level;

ALTER TABLE `Building` ADD INDEX `land_id_idx`(`land_id`),
 ADD INDEX `building_type_idx`(`building_type_id`);

ALTER TABLE `Quest` ADD COLUMN `day_offered` INTEGER  DEFAULT NULL AFTER `days_to_complete`;

INSERT INTO `Quest_Type`(quest_type, owner_type,description) values ('take_over_town', 'kingdom', 'Take Over A Town');

set @take_over_town_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'take_over_town');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@take_over_town_id , 'Town To Take Over');

ALTER TABLE `Kingdom` ADD COLUMN `active` TINYINT  NOT NULL DEFAULT 1 AFTER `gold`;

INSERT INTO `Quest_Type`(quest_type, owner_type, description) values ('create_garrison', 'kingdom', 'Create a Garrison');

set @create_garrison_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'create_garrison');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@create_garrison_id, 'Location To Create');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@create_garrison_id, 'Days To Hold');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@create_garrison_id, 'Created');

ALTER TABLE `Party` ADD COLUMN `last_allegiance_change` INTEGER  DEFAULT NULL AFTER `kingdom_id`;

ALTER TABLE `Land` ADD COLUMN `claimed_by_id` INTEGER  DEFAULT NULL,
 ADD COLUMN `claimed_by_type` VARCHAR(50)  DEFAULT NULL;

ALTER TABLE `Quest_Param_Name` ADD COLUMN `variable_type` VARCHAR(50),
 ADD COLUMN `user_settable` TINYINT  NOT NULL DEFAULT 0,
 ADD COLUMN `min_val` INTEGER  DEFAULT NULL,
 ADD COLUMN `max_val` INTEGER  DEFAULT NULL,
 ADD COLUMN `default_val` VARCHAR(255)  DEFAULT NULL;

UPDATE `Quest_Param_Name` set variable_type = 'Land', user_settable = 1 where quest_param_name = 'Building Location';
UPDATE `Quest_Param_Name` set variable_type = 'Building_Type', user_settable = 1 where quest_param_name = 'Building Type';
UPDATE `Quest_Param_Name` set default_val = '0' where quest_param_name = 'Built';

UPDATE `Quest_Param_Name` set variable_type = 'int', user_settable = 1, min_val = 10, max_val = 50 where quest_param_name = 'Amount To Claim';
UPDATE `Quest_Param_Name` set default_val = '0' where quest_param_name = 'Amount Claimed';

UPDATE `Quest_Param_Name` set variable_type = 'Town', user_settable = 1 where quest_param_name = 'Town To Take Over';

UPDATE `Quest_Param_Name` set variable_type = 'int', user_settable = 1, min_val = 5, max_val = 20 where quest_param_name = 'Days To Hold';
UPDATE `Quest_Param_Name` set variable_type = 'Land', user_settable = 1 where quest_param_name = 'Location To Create';
UPDATE `Quest_Param_Name` set default_val = '0' where quest_param_name = 'Created';

ALTER TABLE `Quest_Type` ADD COLUMN `long_desc` VARCHAR(1000)  DEFAULT NULL AFTER `description`;

UPDATE `Quest_Type` set long_desc = 'Order a party to construct a building in the sector specified' where quest_type = 'construct_building';
UPDATE `Quest_Type` set long_desc = 'Order a party to create a garrison in the sector specified, and hold the garrison for a given number of days' where quest_type = 'create_garrison';
UPDATE `Quest_Type` set long_desc = 'Request that a party claims a certain number of land for the Kingdom' where quest_type = 'claim_land';
UPDATE `Quest_Type` set long_desc = 'Request that a party takes over a town, installs a mayor, and changes the town\s allegiance to that of the Kingdom' where quest_type = 'take_over_town';

CREATE TABLE `Kingdom_Messages` (
  `message_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `kingdom_id` INTEGER  NOT NULL,
  `day_id` INTEGER  NOT NULL,
  `message` VARCHAR(1000)  NOT NULL,
  PRIMARY KEY (`message_id`),
  INDEX `kingdom_id_idx`(`kingdom_id`),
  INDEX `day_id_idx`(`day_id`)
)
ENGINE = InnoDB;

CREATE TABLE `Party_Kingdom` (
  `party_id` INTEGER  NOT NULL,
  `kingdom_id` INTEGER  NOT NULL,
  `loyalty` INTEGER  NOT NULL DEFAULT 0,
  PRIMARY KEY (`party_id`, `kingdom_id`)
)
ENGINE = InnoDB;


