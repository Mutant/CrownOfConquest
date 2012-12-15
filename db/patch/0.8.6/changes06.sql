CREATE TABLE `Player_Reward_Vote` (
  `vote_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `player_id` INTEGER  NOT NULL,
  `link_id` INTEGER  NOT NULL,
  `vote_date` DATETIME  NOT NULL,
  PRIMARY KEY (`vote_id`)
)
ENGINE = InnoDB;

