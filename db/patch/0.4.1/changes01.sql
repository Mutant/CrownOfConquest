ALTER TABLE `Mapped_Sectors` ADD COLUMN `phantom_dungeon` TINYINT  NOT NULL DEFAULT 0 AFTER `party_id`;

ALTER TABLE `Door` ADD COLUMN `type` VARCHAR(255)  NOT NULL DEFAULT 'standard' AFTER `position_id`;
ALTER TABLE `Door` ADD COLUMN `state` VARCHAR(255)  NOT NULL DEFAULT 'closed' AFTER `type`;

ALTER TABLE `Combat_Log` MODIFY COLUMN `land_id` INTEGER  DEFAULT NULL,
 ADD COLUMN `dungeon_grid_id` INTEGER  DEFAULT NULL AFTER `session`;