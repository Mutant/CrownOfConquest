ALTER TABLE `Player` ADD COLUMN `bug_manager` TINYINT(1)  NOT NULL DEFAULT 0,
 ADD COLUMN `contact_manager` TINYINT(1)  NOT NULL DEFAULT 0;

UPDATE `Player` SET bug_manager = 1, contact_manager = 1 where player_id=6;
