ALTER TABLE `Player` MODIFY COLUMN `email` VARCHAR(255) DEFAULT NULL;
ALTER TABLE `Player` MODIFY COLUMN `verification_code` VARCHAR(255) DEFAULT NULL;

CREATE TABLE `Kingdom_Relationship` (
  `relationship_id` int(11) NOT NULL AUTO_INCREMENT,
  `kingdom_id` int(11) NOT NULL,
  `with` int(11) NOT NULL,
  `begun` int(11) DEFAULT NULL,
  `ended` int(11) DEFAULT NULL,
  `type` varchar(40) NOT NULL DEFAULT 'neutral',
  PRIMARY KEY (`relationship_id`),
  KEY `kingdom_id_idx` (`kingdom_id`),
  KEY `with_idx` (`with`),
  KEY `ended_idx` (`ended`)
) ENGINE=InnoDB;

ALTER TABLE `Garrison` ADD COLUMN `attack_friendly_parties` TINYINT(4)  NOT NULL DEFAULT 0;

