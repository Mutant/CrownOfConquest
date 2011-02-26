ALTER TABLE `Player` ADD COLUMN `email_hash` VARCHAR(255)  AFTER `promo_code_id`;

ALTER TABLE `Character` ADD COLUMN `online_cast_chance` INTEGER  NOT NULL DEFAULT 0 AFTER `offline_cast_chance`;

