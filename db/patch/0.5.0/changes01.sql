CREATE TABLE `Road` (
  `road_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `position` VARCHAR(40)  NOT NULL,
  `land_id` INTEGER  NOT NULL,
  PRIMARY KEY (`road_id`),
  INDEX `land_id_idx`(`land_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Player` ADD COLUMN `send_daily_report` TINYINT(1) NOT NULL DEFAULT 1 AFTER `warned_for_deletion`;
