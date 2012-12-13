ALTER TABLE `Promo_Code` ADD COLUMN `uses_remaining` INT  NOT NULL DEFAULT 0;
UPDATE `Promo_Code` SET uses_remaining = 1 where used = 0;
ALTER TABLE `game`.`Promo_Code` DROP COLUMN `used`;


