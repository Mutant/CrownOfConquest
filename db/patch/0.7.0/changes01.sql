INSERT into Spell (spell_name, description, points, class_id, target, combat, non_combat, hidden) 
  values ('Portal', 'Allows the party to return to the wilderness from anywhere in a dungeon', 6, 3, 'party', 0, 1, 0);

UPDATE Land set creature_threat = -60 where creature_threat <= -60;

ALTER TABLE `Town` ADD COLUMN `advisor_fee` INTEGER  NOT NULL DEFAULT 0 AFTER `last_election`;

CREATE TABLE `Dungeon_Teleporter` (
  `teleporter_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `dungeon_grid_id` INTEGER  NOT NULL,
  `destination_id` INTEGER ,
  `invisible` TINYINT  NOT NULL DEFAULT 0,
  PRIMARY KEY (`teleporter_id`),
  INDEX `dungeon_fk`(`dungeon_grid_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Character` ADD COLUMN `strength_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `encumbrance`,
 ADD COLUMN `intelligence_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `strength_bonus`,
 ADD COLUMN `agility_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `intelligence_bonus`,
 ADD COLUMN `divinity_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `agility_bonus`,
 ADD COLUMN `constitution_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `divinity_bonus`;



