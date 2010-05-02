CREATE  TABLE IF NOT EXISTS `Garrison` (
  `garrison_id` INT NOT NULL AUTO_INCREMENT ,
  `land_id` INT(11) NOT NULL ,
  `party_id` INT(11) NOT NULL ,
  `creature_attack_mode` VARCHAR(45) NULL ,
  `party_attack_mode` VARCHAR(45) NULL ,
  `flee_threshold` INT DEFAULT 70,
  `in_combat_with` INT NULL,
  `gold` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`garrison_id`) ,
  INDEX `fk_Garrison_Land1` (`land_id` ASC) ,
  INDEX `fk_Garrison_Party1` (`party_id` ASC) ,
  CONSTRAINT `fk_Garrison_Land1`
    FOREIGN KEY (`land_id` )
    REFERENCES `Land` (`land_id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Garrison_Party1`
    FOREIGN KEY (`party_id` )
    REFERENCES `Party` (`party_id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB

CREATE  TABLE IF NOT EXISTS `Combat_Log_Messages` (
  `log_message_id` INT NOT NULL AUTO_INCREMENT ,
  `round` INT NULL ,
  `message` TEXT NULL ,
  `combat_log_id` INT(11) NOT NULL ,
  `opponent_number` INT NOT NULL ,
  INDEX `fk_Combat_Log_Messages_Combat_Log1` (`combat_log_id` ASC) ,
  PRIMARY KEY (`log_message_id`) ,
  CONSTRAINT `fk_Combat_Log_Messages_Combat_Log1`
    FOREIGN KEY (`combat_log_id` )
    REFERENCES `Combat_Log` (`combat_log_id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB

ALTER TABLE `Character` ADD COLUMN `garrison_id` INT  NULL AFTER `gender`;
