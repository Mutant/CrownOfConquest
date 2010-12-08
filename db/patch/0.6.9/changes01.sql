update Land set creature_threat = 0;

update Creature_Type set image = 'wispsmall.png' where creature_type = 'Wisp';
update Creature_Type set image = 'wyvernsmall.png' where creature_type = 'Wyvern';
update Creature_Type set image = 'orcgruntsmall.png' where creature_type = 'Orc Grunt';
update Creature_Type set image = 'hobgoblinsmall.png' where creature_type = 'Hobgoblin';
update Creature_Type set image = 'firedragonsmall.png' where creature_type = 'Fire Dragon';
update Creature_Type set image = 'golddragonsmall.png' where creature_type = 'Gold Dragon';
update Creature_Type set image = 'silverdragonsmall.png' where creature_type = 'Silver Dragon';

ALTER TABLE `Character` ADD COLUMN `status` VARCHAR(20)  DEFAULT NULL AFTER `mayor_of`,
 ADD COLUMN `status_context` BIGINT  DEFAULT NULL AFTER `status`;

ALTER TABLE `Character` ADD INDEX `status_context_id`(`status`, `status_context`);

insert into Enchantments (enchantment_name, must_be_equipped, one_per_item) values ('featherweight', 0, 1);

set @ench_id = (select enchantment_id from Enchantments where enchantment_name = 'featherweight');

insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Melee Weapon'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category= 'Armour'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Head Gear'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Ranged Weapon'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Shield'));

