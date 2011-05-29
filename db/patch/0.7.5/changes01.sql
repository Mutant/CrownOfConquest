ALTER TABLE `Town` ADD COLUMN `character_heal_budget` INTEGER  NOT NULL DEFAULT 0 AFTER `advisor_fee`;

ALTER TABLE `Garrison` ADD COLUMN `attack_parties_from_kingdom` TINYINT  NOT NULL DEFAULT 0 AFTER `name`;

