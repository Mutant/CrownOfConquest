ALTER TABLE `Character` ADD COLUMN `resist_fire` INTEGER  NOT NULL DEFAULT 0 AFTER `skill_points`,
 ADD COLUMN `resist_fire_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_fire`,
 ADD COLUMN `resist_ice` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_fire_bonus`,
 ADD COLUMN `resist_ice_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_ice`,
 ADD COLUMN `resist_poison` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_ice_bonus`,
 ADD COLUMN `resist_poison_bonus` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_poison`;

UPDATE `Spell` set points = 5 where spell_name = 'Flame';
INSERT INTO `Spell`(spell_name, description, points, class_id, combat, non_combat, target)
	VALUES ('Ice Bolt', 'Shoots a bolt of ice at the opponent, damaging them, and freezing them', 7, (select class_id from Class where class_name = 'Mage'), 1, 0, 'creature');

INSERT INTO `Spell`(spell_name, description, points, class_id, combat, non_combat, target)
	VALUES ('Poison Blast', 'Sends a poisonous blast to the opponent, damaging them slowly', 6, (select class_id from Class where class_name = 'Mage'), 1, 0, 'creature');

INSERT INTO `Enchantments` (enchantment_name, must_be_equipped, one_per_item) values ('resistances', 1, 1);

set @ench_id = (select enchantment_id from Enchantments where enchantment_name = 'resistances');

insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Melee Weapon'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category= 'Armour'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Head Gear'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Ranged Weapon'));
insert into Enchantment_Item_Category (enchantment_id, item_category_id) values (@ench_id, (select item_category_id from Item_Category where item_category = 'Shield'));

ALTER TABLE `Party` ADD COLUMN `description` VARCHAR(5000) DEFAULT NULL;

ALTER TABLE `Kingdom` ADD COLUMN `description` VARCHAR(5000) DEFAULT NULL;

