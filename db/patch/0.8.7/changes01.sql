INSERT into `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, image, usable, height, width)
	VALUES ("Book Of Past Lives", (select item_category_id FROM Item_Category where item_category = 'Magical'), 100000, 1, 10, 'bookofpastlives.png', 1, 1, 1);
