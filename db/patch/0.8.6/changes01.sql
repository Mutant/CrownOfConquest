INSERT into Spell(spell_name, description, points, class_id, combat, non_combat, target) 
	values ('Cleanse', 'Removes all negative effects from a character in the party', 8, 3, 1, 1, 'character');

UPDATE Building_Type set labor_to_raze = 60 where name = 'Tower';
UPDATE Building_Type set labor_to_raze = 80 where name = 'Fort';
UPDATE Building_Type set labor_to_raze = 100 where name = 'Castle';

ALTER TABLE `Party_Messages` ADD INDEX `type_idx`(`type`),
 ADD INDEX `day_id_idx`(`day_id`),
 ADD INDEX `sender_id_idx`(`sender_id`),
 ADD INDEX `party_id_ix`(`party_id`);

ALTER TABLE `Day_Log` ADD INDEX `day_id_idx`(`day_id`);

UPDATE Building_Type set land_claim_range = 2 where name = 'Tower';
UPDATE Building_Type set land_claim_range = 3 where name = 'Fort';
UPDATE Building_Type set land_claim_range = 4 where name = 'Castle';

ALTER TABLE `Garrison` ADD COLUMN `established` DATETIME  NOT NULL;
UPDATE `Garrison` set established = now();

ALTER TABLE `Garrison` ADD COLUMN `claim_land_order` TINYINT(4)  NOT NULL DEFAULT 0;

UPDATE `Creature_Type` set image = 'demonking.png' where creature_type = 'Demon King';
UPDATE `Creature_Type` set image = 'demonlord.png' where creature_type = 'Demon Lord';
UPDATE `Creature_Type` set image = 'demonspawn.png' where creature_type = 'Devils Spawn';
UPDATE `Creature_Type` set image = 'fireelemental.png' where creature_type = 'Fire Elemental';
UPDATE `Creature_Type` set image = 'greaterdemon.png' where creature_type = 'Greater Demon';
UPDATE `Creature_Type` set image = 'icedragon.png' where creature_type = 'Ice Dragon';
UPDATE `Creature_Type` set image = 'lesserdemon.png' where creature_type = 'Lesser Demon';
UPDATE `Creature_Type` set image = 'platinumdragon.png' where creature_type = 'Platinum Dragon';
UPDATE `Creature_Type` set image = 'wrait.png' where creature_type = 'Wraith';


