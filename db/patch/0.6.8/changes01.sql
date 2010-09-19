CREATE TABLE `Election` (
  `election_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `town_id` INTEGER  NOT NULL,
  `scheduled_day` INTEGER  NOT NULL,
  `status` VARCHAR(20)  NOT NULL DEFAULT 'Open',
  PRIMARY KEY (`election_id`)
)
ENGINE = InnoDB;

CREATE TABLE `Election_Candidate` (
  `election_id` INTEGER  NOT NULL,
  `character_id` INTEGER  NOT NULL
)
ENGINE = InnoDB;

