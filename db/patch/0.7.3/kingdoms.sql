CREATE TABLE .`Kingdom` (
  `kingdom_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255)  NOT NULL,
  `colour` VARCHAR(255)  NOT NULL,
  PRIMARY KEY (`kingdom_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Land` ADD COLUMN `kingdom_id` INTEGER  AFTER `creature_threat`,
 ADD INDEX `kingdom_idx`(`kingdom_id`);

