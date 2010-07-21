ALTER TABLE `Memorised_Spells` ADD COLUMN `cast_offline` TINYINT  NOT NULL DEFAULT 0 AFTER `memorise_count_tomorrow`;
ALTER TABLE `Character` ADD COLUMN `offline_cast_chance` INTEGER  NOT NULL DEFAULT 35 AFTER `garrison_id`;
ALTER TABLE `Party` ADD COLUMN `combat_type` VARCHAR(255)  AFTER `flee_threshold`;
ALTER TABLE `Items` ADD COLUMN `land_id` INTEGER  DEFAULT NULL AFTER `garrison_id`,
 ADD INDEX `land_id`(`land_id`);


