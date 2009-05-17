ALTER TABLE `Character` ADD COLUMN `gender` VARCHAR(50)  NOT NULL DEFAULT 'male' AFTER `last_combat_param2`;

ALTER TABLE `Item_Variable` DROP COLUMN `item_variable_name`;

CREATE TABLE `Party_Effect` (
  `party_id` INTEGER  NOT NULL,
  `effect_id` INTEGER  NOT NULL,
  PRIMARY KEY (`party_id`, `effect_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Effect` ADD COLUMN `time_type` VARCHAR(50)  NOT NULL DEFAULT 'round' AFTER `combat`;

ALTER TABLE `Combat_Log` ADD INDEX `log_count_idx`(`opponent_1_id`, `opponent_2_id`, `opponent_1_type`, `opponent_2_type`, `encounter_ended`);

INSERT into `Spell` (spell_name, description, points, class_id, combat, non_combat, target, hidden)
	values ('Watcher', 'Creates a "Watcher" force, that stays with the party and determines how the party will fare in combat in relation to a particular group of creatures',
	        10, 4, 0, 1, 'party', 0); 