ALTER TABLE `Character` ADD COLUMN `resist_fire` INTEGER  NOT NULL DEFAULT 0 AFTER `skill_points`,
 ADD COLUMN `resist_fire_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_fire`,
 ADD COLUMN `resist_ice` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_fire_bonus`,
 ADD COLUMN `resist_ice_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_ice`,
 ADD COLUMN `resist_poison` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_ice_bonus`,
 ADD COLUMN `resist_poison_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_poison`;

