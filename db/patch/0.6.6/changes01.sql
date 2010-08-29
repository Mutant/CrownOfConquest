ALTER TABLE `Character` ADD COLUMN `creature_group_id` BIGINT  DEFAULT NULL AFTER `offline_cast_chance`,
 ADD INDEX `cg_id_idx`(`creature_group_id`);

ALTER TABLE `Town` ADD COLUMN `pending_mayor` BIGINT  DEFAULT NULL,
 ADD INDEX `pending_mayor_idx`(`pending_mayor`);

ALTER TABLE `Creature_Group` MODIFY COLUMN `creature_group_id` BIGINT  NOT NULL AUTO_INCREMENT;

ALTER TABLE `Character` ADD COLUMN `mayor_of` BIGINT(20)  AFTER `creature_group_id`,
 ADD INDEX `mayor_idx`(`mayor_of`);

ALTER TABLE `Town` ADD COLUMN `gold` INT  NOT NULL DEFAULT 0 AFTER `pending_mayor`,
 ADD COLUMN `peasant_tax` INT  NOT NULL DEFAULT 0 AFTER `gold`;

ALTER TABLE `Town` ADD COLUMN `base_party_tax` INTEGER  NOT NULL DEFAULT 0 AFTER `peasant_tax`,
 ADD COLUMN `party_tax_level_step` INTEGER  NOT NULL DEFAULT 0 AFTER `base_party_tax`;

ALTER TABLE `Town` ADD COLUMN `sales_tax` INTEGER  NOT NULL DEFAULT 0 AFTER `party_tax_level_step`;

ALTER TABLE `Shop` DROP COLUMN `cost_modifier`;

ALTER TABLE `Town_History` ADD COLUMN `type` VARCHAR(30)  NOT NULL DEFAULT 'news' AFTER `date_recorded`,
 ADD COLUMN `value` VARCHAR(200)  DEFAULT NULL AFTER `type`;

ALTER TABLE `Town` ADD COLUMN `tax_modified_today` TINYINT  NOT NULL DEFAULT 0 AFTER `sales_tax`;

CREATE TABLE `Town_Guards` (
  `town_id` INTEGER  NOT NULL,
  `creature_type_id` INTEGER  NOT NULL,
  `amount` INTEGER  NOT NULL,
  PRIMARY KEY (`town_id`, `creature_type_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Town` ADD COLUMN `mayor_rating` INTEGER  NOT NULL DEFAULT 0 AFTER `tax_modified_today`;

ALTER TABLE `Town` ADD COLUMN `peasant_state` VARCHAR(200)  DEFAULT NULL AFTER `mayor_rating`;

ALTER TABLE `Creature_Type` ADD COLUMN `hire_cost` INTEGER  DEFAULT NULL AFTER `creature_category_id`;

UPDATE `Creature_Type` set hire_cost = '20' where creature_type = 'Rookie Town Guard';
UPDATE `Creature_Type` set hire_cost = '40' where creature_type = 'Seasoned Town Guard';
UPDATE `Creature_Type` set hire_cost = '85' where creature_type = 'Veteran Town Guard';

ALTER TABLE `Garrison` DROP FOREIGN KEY `fk_Garrison_Land1`,
 DROP FOREIGN KEY `fk_Garrison_Party1`;

ALTER TABLE `Town` ADD COLUMN `pending_mayor_date` DATETIME  DEFAULT NULL AFTER `peasant_state`;






