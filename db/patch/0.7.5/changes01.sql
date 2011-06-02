ALTER TABLE `Town` ADD COLUMN `character_heal_budget` INTEGER  NOT NULL DEFAULT 0;

ALTER TABLE `Garrison` ADD COLUMN `attack_parties_from_kingdom` TINYINT  NOT NULL DEFAULT 0;

CREATE TABLE `Party_Mayor_History` (
  `history_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `mayor_name` VARCHAR(255)  NOT NULL,
  `got_mayoralty_day` INTEGER  NOT NULL,
  `lost_mayoralty_day` INTEGER ,
  `creature_group_id` INTEGER ,
  `lost_mayoralty_to` VARCHAR(255) ,
  `lost_method` VARCHAR(255) ,
  `character_id` INTEGER  NOT NULL,
  `town_id` INTEGER  NOT NULL,
  `party_id` INTEGER  NOT NULL,
  PRIMARY KEY (`history_id`)
)
ENGINE = InnoDB;

ALTER TABLE `game`.`Item_Type` ADD COLUMN `usable` TINYINT  NOT NULL DEFAULT 0;

INSERT INTO `Item_Category` (item_category, hidden, auto_add_to_shop, findable) values ('Magical', 0, 0, 1);

set @magical_cat_id = (select item_category_id from Item_Category where item_category = 'Magical');
INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Healing', @magical_cat_id, 100, 20, 5, 1, 'redpotion.png');

INSERT INTO `Item_Variable_Name` (item_variable_name, item_category_id, create_on_insert) values ('Quantity', @magical_cat_id, 1);
set @ivn = (select item_variable_name_id from Item_Variable_Name where item_category_id = @magical_cat_id);

INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Healing'), @ivn);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Strength', @magical_cat_id, 1000, 1, 5, 1, 'greenpotion.png');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Strength'), @ivn);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Agility', @magical_cat_id, 1000, 1, 5, 1, 'greenpotion.png');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Agility'), @ivn);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Constitution', @magical_cat_id, 1000, 1, 5, 1, 'greenpotion.png');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Constitution'), @ivn);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Divinity', @magical_cat_id, 1000, 1, 5, 1, 'greenpotion.png');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Divinity'), @ivn);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Intelligence', @magical_cat_id, 1000, 1, 5, 1, 'greenpotion.png');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Intelligence'), @ivn);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Potion of Diffusion', @magical_cat_id, 750, 8, 5, 1, 'messypotion.png');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Potion of Diffusion'), @ivn);

ALTER TABLE `Party` ADD INDEX `in_combat_with_idx`(`in_combat_with`);


