CREATE TABLE `Skill` (
  `skill_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `skill_name` VARCHAR(40)  NOT NULL,
  `type` VARCHAR(40)  NOT NULL,
  `description` VARCHAR(2000) NOT NULL,
  PRIMARY KEY (`skill_id`),
  INDEX `type_index`(`type`)
)
ENGINE = InnoDB;

CREATE TABLE `Character_Skill` (
  `character_id` INTEGER  NOT NULL,
  `skill_id` INTEGER  NOT NULL,
  `level` INTEGER  NOT NULL,
  PRIMARY KEY (`character_id`, `skill_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Character` ADD COLUMN `skill_points` INTEGER  NOT NULL DEFAULT 0;


