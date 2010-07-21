ALTER TABLE `Character` ADD COLUMN `creature_group_id` BIGINT  DEFAULT NULL AFTER `offline_cast_chance`,
 ADD INDEX `cg_id_idx`(`creature_group_id`);

ALTER TABLE `Town` ADD COLUMN `mayor` BIGINT  DEFAULT NULL AFTER `discount_threshold`,
 ADD INDEX `mayor_idx`(`mayor`);

