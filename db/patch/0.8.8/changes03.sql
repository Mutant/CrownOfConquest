set @magical_cat_id = (select item_category_id from Item_Category where item_category = 'Magical');

INSERT INTO `Item_Variable_Name` (item_variable_name, item_category_id, create_on_insert) values ('Max Level', @magical_cat_id, 1);

set @ivn = (select item_variable_name_id from Item_Variable_Name where item_variable_name = 'Max Level');

INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id, special) values (0, 1, 1, (select item_type_id from Item_Type where item_type = 'Book Of Past Lives'), @ivn, 1);

UPDATE `Item_Type` set base_cost = '10000' where item_type = 'Book of Past Lives';
