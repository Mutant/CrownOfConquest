set @magical_cat_id = (select item_category_id from Item_Category where item_category = 'Magical');
INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Scroll', @magical_cat_id, 20, 30, 0.1, 1, 'writtenscroll1.png');

ALTER TABLE `Item_Variable_Params` ADD COLUMN `special` TINYINT  NOT NULL DEFAULT 0;

INSERT INTO `Item_Variable_Name` (item_variable_name, item_category_id, create_on_insert) values ('Spell', @magical_cat_id, 1);

set @ivn2 = (select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Spell');

INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id, special) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Scroll'), @ivn2, 1);



