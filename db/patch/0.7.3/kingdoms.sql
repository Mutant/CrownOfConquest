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

ALTER TABLE `Quest_Type` ADD COLUMN `owner_type` VARCHAR(40)  NOT NULL DEFAULT 'town' AFTER `prevalence`;

INSERT INTO `Quest_Type`(quest_type, owner_type) values ('construct_building', 'kingdom');

set @construct_building_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'construct_building');

INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@construct_building_id, 'Building Location');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@construct_building_id, 'Building Type');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@construct_building_id, 'Built');

INSERT INTO `Quest_Type`(quest_type, owner_type) values ('claim_land', 'kingdom');
set @claim_land_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'claim_land');

INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@claim_land_id, 'Amount To Claim');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@claim_land_id, 'Amount Claimed');

ALTER TABLE `Party` ADD COLUMN `kingdom_id` INTEGER  DEFAULT NULL AFTER `combat_type`,
 ADD INDEX `kingdom_id_idx`(`kingdom_id`),
 ADD INDEX `player_id_idx`(`player_id`);

ALTER TABLE `Building_Type` ADD COLUMN `land_claim_range` INTEGER  NOT NULL DEFAULT 1 AFTER `constr_image`;

update `Building_Type` set land_claim_range = level + 1;

ALTER TABLE `Building` ADD INDEX `land_id_idx`(`land_id`),
 ADD INDEX `building_type_idx`(`building_type_id`);

ALTER TABLE `Quest` ADD COLUMN `day_offered` INTEGER  DEFAULT NULL AFTER `days_to_complete`;

INSERT INTO `Quest_Type`(quest_type, owner_type) values ('take_over_town', 'kingdom');

set @take_over_town_id = (select quest_type_id FROM `Quest_Type` where quest_type = 'take_over_town');
INSERT INTO `Quest_Param_Name`(quest_type_id, quest_param_name) values (@take_over_town_id , 'Town To Take Over');



