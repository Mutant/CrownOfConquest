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

INSERT INTO Spell (spell_name, description, points, class_id, combat, non_combat, target, hidden)
	VALUES ('Detonate', 'Creates a magical bomb that will detonate after a few minutes. If detonated in a town\'s castle during a raid, or adjacent to a building in the wilderness, the building\'s upgrade runes may be damaged, temprorarily or permanently. In castles, more damage is likely to be done if bombs are planted away from the stairs. Requires 1 Vial of Dragons Blood that will be used up during casting', 10, 4, 0, 1, 'party', 0);

INSERT INTO Item_Type (item_type, item_category_id, base_cost, prevalence, weight, image, usable) VALUES ('Vial of Dragons Blood',12,50000,1,'3.00','dbloodvial.png',0);

INSERT INTO Item_Variable_Params (keep_max, min_value, max_value, item_type_id, item_variable_name_id)
	values (0,1,1,(select item_type_id from Item_Type where item_type = 'Vial of Dragons Blood'), 
	(select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Quantity' and item_category_id = 12));

CREATE TABLE `Bomb` (
  `bomb_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `land_id` INTEGER ,
  `dungeon_grid_id` INTEGER ,
  `planted` DATETIME  NOT NULL,
  `party_id` INTEGER  NOT NULL,
  `level` INTEGER  NOT NULL,
  `detonated` DATETIME  DEFAULT NULL,
  PRIMARY KEY (`bomb_id`),
  INDEX `land_id_idx`(`land_id`),
  INDEX `d_grid_idx`(`dungeon_grid_id`),
  INDEX `party_id_idx`(`party_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Building_Upgrade` ADD COLUMN `damage` INTEGER  NOT NULL DEFAULT 0 AFTER `level`,
 ADD COLUMN `damage_last_done` DATETIME AFTER `damage`;

ALTER TABLE `Bomb` ADD INDEX `planted_idx`(`planted`);

ALTER TABLE `Dungeon_Room` ADD COLUMN `tileset` VARCHAR(100)  NOT NULL;

