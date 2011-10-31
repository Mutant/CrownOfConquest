ALTER TABLE `Player` ADD COLUMN `screen_width` VARCHAR(255)  NOT NULL DEFAULT 'auto',
 ADD COLUMN `screen_height` VARCHAR(255)  NOT NULL DEFAULT 'auto';

ALTER TABLE `Player_Login` ADD COLUMN `screen_height` INTEGER,
 ADD COLUMN `screen_width` INTEGER;

update Levels set xp_needed = 3000 where level_number = 5;
update Levels set xp_needed = 5000 where level_number = 6;
update Levels set xp_needed = 7000 where level_number = 7;
update Levels set xp_needed = 9200 where level_number = 8;
update Levels set xp_needed = 11400 where level_number = 9;
update Levels set xp_needed = 13600 where level_number = 10;
update Levels set xp_needed = 16000 where level_number = 11;
update Levels set xp_needed = 18500 where level_number = 12;
update Levels set xp_needed = 21000 where level_number = 13;
update Levels set xp_needed = 24000 where level_number = 14;

update Creature_Type set image = 'claygolem.png' where creature_type = 'Clay Golem';
update Creature_Type set image = 'irongolem.png' where creature_type = 'Iron Golem';
update Creature_Type set image = 'stonegolem.png' where creature_type = 'Stone Golem';
update Creature_Type set image = 'rookieguard.png' where creature_type = 'Rookie Town Guard';
update Creature_Type set image = 'seasonedguard.png' where creature_type = 'Seasoned Town Guard';
update Creature_Type set image = 'veteranguard.png' where creature_type = 'Veteran Town Guard';
update Creature_Type set image = 'cyclops.png' where creature_type = 'Cyclopse';
