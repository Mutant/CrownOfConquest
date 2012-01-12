ALTER TABLE `Character` ADD COLUMN `resist_fire` INTEGER  NOT NULL DEFAULT 0 AFTER `skill_points`,
 ADD COLUMN `resist_fire_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_fire`,
 ADD COLUMN `resist_ice` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_fire_bonus`,
 ADD COLUMN `resist_ice_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_ice`,
 ADD COLUMN `resist_poison` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_ice_bonus`,
 ADD COLUMN `resist_poison_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_poison`;

UPDATE `Spell` set points = 5 where spell_name = 'Flame';
INSERT INTO `Spell`(spell_name, description, points, class_id, combat, non_combat, target)
	VALUES ('Ice Bolt', 'Shoots a bolt of ice at the opponent, damaging them, and freezing them', 7, (select class_id from Class where class_name = 'Mage'), 1, 0, 'creature');

INSERT INTO `Spell`(spell_name, description, points, class_id, combat, non_combat, target)
	VALUES ('Poison Blast', 'Sends a poisonous blast to the opponent, damaging them slowly', 6, (select class_id from Class where class_name = 'Mage'), 1, 0, 'creature');
