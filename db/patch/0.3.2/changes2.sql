ALTER TABLE `Character` ADD COLUMN `gender` VARCHAR(50)  NOT NULL DEFAULT 'male' AFTER `last_combat_param2`;

ALTER TABLE `Item_Variable` DROP COLUMN `item_variable_name`;