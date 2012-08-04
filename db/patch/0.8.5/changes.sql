update Tip set tip = 'You don\'t need to log into Crown of Conquest every day to make use of all your turns. Turns will accumulate for a few days, before you have to use them or lose them.'
       where tip_id = 9;

ALTER TABLE `Player` ADD COLUMN `display_town_leave_warning` TINYINT(1)  NOT NULL DEFAULT 1;

ALTER TABLE `sessions` ADD COLUMN `created` TIMESTAMP  NOT NULL AFTER `expires`;

CREATE TABLE `Day_Stats` (
  `date` DATE  NOT NULL,
  `visitors` INTEGER  NOT NULL,
  PRIMARY KEY (`date`)
)
ENGINE = InnoDB;
