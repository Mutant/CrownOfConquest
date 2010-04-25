CREATE  TABLE IF NOT EXISTS `Garrison` (
  `garrison_id` INT NOT NULL AUTO_INCREMENT ,
  `land_id` INT(11) NOT NULL ,
  `party_id` INT(11) NOT NULL ,
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
ENGINE = InnoDB;

ALTER TABLE `Character` ADD COLUMN `garrison_id` INT  NULL AFTER `gender`;
