ALTER TABLE `Town` ADD COLUMN `character_heal_budget` INTEGER  NOT NULL DEFAULT 0;

ALTER TABLE `Garrison` ADD COLUMN `attack_parties_from_kingdom` TINYINT  NOT NULL DEFAULT 0;

CREATE TABLE `Party_Mayor_History` (
  `history_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `mayor_name` VARCHAR(255)  NOT NULL,
  `got_mayoralty_day` INTEGER  NOT NULL,
  `lost_mayoralty_day` INTEGER ,
  `creature_group_id` INTEGER ,
  `lost_mayoralty_to` VARCHAR(255) ,
  `lost_method` VARCHAR(255) ,
  `character_id` INTEGER  NOT NULL,
  `town_id` INTEGER  NOT NULL,
  `party_id` INTEGER  NOT NULL,
  PRIMARY KEY (`history_id`)
)
ENGINE = InnoDB;
