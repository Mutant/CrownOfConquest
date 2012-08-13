CREATE TABLE `game`.`Party_Day_Stats` (
  `date` DATE  NOT NULL,
  `party_id` INTEGER  NOT NULL,
  `turns_used` INTEGER  NOT NULL,
  PRIMARY KEY (`date`, `party_id`)
)
ENGINE = InnoDB;

