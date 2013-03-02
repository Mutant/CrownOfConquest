--INSERT into `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, image, usable, height, width)
--	VALUES ("Book Of Past Lives", (select item_category_id FROM Item_Category where item_category = 'Magical'), 100000, 1, 10, 'bookofpastlives.png', 1, 1, 1);

UPDATE Creature_Type set image = 'revenant.png' where creature_type = 'Revenant';
UPDATE Creature_Type set image = 'wererat.png' where creature_type = 'Wererat';
UPDATE Creature_Type set image = 'weretiger.png' where creature_type = 'Weretiger';
UPDATE Creature_Type set image = 'werewolf.png' where creature_type = 'Werewolf';
