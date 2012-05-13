ALTER TABLE `Items` ADD UNIQUE INDEX `unique_equip_slot`(`character_id`, `equip_place_id`);

set @cat_id = (select item_category_id from Item_Category where item_category = 'Resource');
INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Blank Scroll', @cat_id, 5, 100, 0.1, 1, 'emptyscroll1.png');

set @var_name_id = (select item_variable_name_id from Item_Variable_Name where item_category_id=@cat_id and item_variable_name='Quantity');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 100, (select item_type_id from `Item_Type` where item_type = 'Blank Scroll'), @var_name_id);
