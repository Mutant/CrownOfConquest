ALTER TABLE `Player` ADD COLUMN `screen_width` VARCHAR(255)  NOT NULL DEFAULT 'auto',
 ADD COLUMN `screen_height` VARCHAR(255)  NOT NULL DEFAULT 'auto';

ALTER TABLE `Player_Login` ADD COLUMN `screen_height` INTEGER,
 ADD COLUMN `screen_width` INTEGER;

