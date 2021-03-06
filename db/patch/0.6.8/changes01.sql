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

ALTER TABLE `Election_Candidate` ADD COLUMN `campaign_spend` INTEGER  NOT NULL DEFAULT 0 AFTER `character_id`;

update `Character` set creature_group_id = null where mayor_of is null and creature_group_id is not null;

ALTER TABLE `Town` ADD COLUMN `last_election` INTEGER  DEFAULT NULL AFTER `pending_mayor_date`;

