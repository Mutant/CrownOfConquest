ALTER TABLE `Day_Log` ADD INDEX `party_id_dx`(`party_id`);

ALTER TABLE `Mapped_Sectors` ADD INDEX `land_party_idx`(`land_id`, `party_id`);

UPDATE `Kingdom` set colour = 'steelblue' where colour = '#408080';

UPDATE `Creature_Type` set image = 'defaultport.png' where image = 'defaultportsmall.png';

UPDATE `Creature_Type` set image = 'troll.png' where image = 'trollmonsmall.png';
UPDATE `Creature_Type` set image = 'goblin.png' where image = 'goblinmonsmall.png';
UPDATE `Creature_Type` set image = 'orc.png' where image = 'orcgruntsmall.png';
UPDATE `Creature_Type` set image = 'ogre.png' where image = 'ogremonsmall.png';
UPDATE `Creature_Type` set image = 'wyvern.png' where image = 'wyvernsmall.png';
UPDATE `Creature_Type` set image = 'golddragon.png' where image = 'golddragonsmall.png';
UPDATE `Creature_Type` set image = 'silverdragon.png' where image = 'silverdragonsmall.png';
UPDATE `Creature_Type` set image = 'firedragon.png' where image = 'firedragonsmall.png';
UPDATE `Creature_Type` set image = 'hobgoblin.png' where image = 'hobgoblinsmall.png';
UPDATE `Creature_Type` set image = 'skeleton.png' where image = 'skelmonsmall.png';
UPDATE `Creature_Type` set image = 'wisp.png' where image = 'wispsmall.png';
