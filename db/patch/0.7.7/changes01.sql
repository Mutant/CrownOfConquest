ALTER TABLE `game`.`Kingdom` ADD COLUMN `capital` INTEGER DEFAULT NULL,
 ADD INDEX `capital_idx`(`capital`);

CREATE TABLE  `game`.`Capital_History` (
  `capital_id` int(11) NOT NULL AUTO_INCREMENT,  
  `kingdom_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `start_date` int(11) NOT NULL,
  `end_date` int(11) DEFAULT NULL,
    PRIMARY KEY (`capital_id`) USING BTREE,
  KEY `kingdom_id_idx` (`kingdom_id`)
) ENGINE=InnoDB
