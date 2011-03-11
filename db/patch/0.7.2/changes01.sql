ALTER TABLE `Player` ADD COLUMN `email_hash` VARCHAR(255)  AFTER `promo_code_id`;

ALTER TABLE `Character` ADD COLUMN `online_cast_chance` INTEGER  NOT NULL DEFAULT 0 AFTER `offline_cast_chance`;

ALTER TABLE `Terrain` DROP COLUMN `image`;

ALTER TABLE `Land` ADD COLUMN `variation` INTEGER  NOT NULL DEFAULT 1 AFTER `kingdom_id`;

UPDATE `Terrain` set terrain_name = 'medium forest', modifier = 5 where terrain_name = 'road';
UPDATE `Terrain` set modifier = 4 where terrain_name = 'light forest';
UPDATE `Terrain` set terrain_name = 'lake' where terrain_name = 'marsh' and modifier = 8;

UPDATE `Building_Type` set image = 'tower.png' where name = 'Tower';
UPDATE `Building_Type` set image = 'fort.png' where name = 'Fort';
UPDATE `Building_Type` set image = 'castle.png' where name = 'Castle';

