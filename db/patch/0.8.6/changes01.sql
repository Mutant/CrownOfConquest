INSERT into Spell(spell_name, description, points, class_id, combat, non_combat, target) 
	values ('Cleanse', 'Removes all negative effects from a character in the party', 8, 3, 1, 1, 'character');

UPDATE building_type set labor_to_raze = 60 where name = 'Tower';
UPDATE building_type set labor_to_raze = 80 where name = 'Fort';
UPDATE building_type set labor_to_raze = 100 where name = 'Castle';

ALTER TABLE `Party_Messages` ADD INDEX `type_idx`(`type`),
 ADD INDEX `day_id_idx`(`day_id`),
 ADD INDEX `sender_id_idx`(`sender_id`),
 ADD INDEX `party_id_ix`(`party_id`);

ALTER TABLE `Day_Log` ADD INDEX `day_id_idx`(`day_id`);

