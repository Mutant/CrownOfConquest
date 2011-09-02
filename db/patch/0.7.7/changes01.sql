ALTER TABLE `Kingdom` ADD COLUMN `capital` INTEGER DEFAULT NULL,
 ADD INDEX `capital_idx`(`capital`);

CREATE TABLE  `Capital_History` (
  `capital_id` int(11) NOT NULL AUTO_INCREMENT,  
  `kingdom_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `start_date` int(11) NOT NULL,
  `end_date` int(11) DEFAULT NULL,
    PRIMARY KEY (`capital_id`) USING BTREE,
  KEY `kingdom_id_idx` (`kingdom_id`)
) ENGINE=InnoDB;

CREATE TABLE `Kingdom_Town` (
  `kingdom_id` INTEGER  NOT NULL,
  `town_id` INTEGER  NOT NULL,
  `loyalty` INTEGER  NOT NULL DEFAULT 0,
  PRIMARY KEY (`kingdom_id`, `town_id`)
)
ENGINE = InnoDB;

