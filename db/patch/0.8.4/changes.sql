ALTER TABLE `Items` ADD UNIQUE INDEX `unique_equip_slot`(`character_id`, `equip_place_id`);

set @cat_id = (select item_category_id from Item_Category where item_category = 'Resource');
INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Blank Scroll', @cat_id, 5, 100, 0.1, 1, 'emptyscroll1.png');

set @var_name_id = (select item_variable_name_id from Item_Variable_Name where item_category_id=@cat_id and item_variable_name='Quantity');
INSERT INTO `Item_Variable_Params` (keep_max, min_value, max_value, item_type_id, item_variable_name_id) values (0, 1, 100, (select item_type_id from `Item_Type` where item_type = 'Blank Scroll'), @var_name_id);

insert into Spell (spell_name, description, points, class_id, combat, non_combat, target)
	values ("Farsight", "Allows the caster to see a map sector from a distance. They will see inside defences of a town or building, giving an indication of how strong they are. The presence of garrisons, dungeons, orbs and guards will also be revealed. The caster's level and the party's proximity to the sector affect the accuracy of the results.", 10, (select class_id from Class where class_name = 'Priest'), 0, 1, "sector");

ALTER TABLE `Item_Category` ADD COLUMN `always_enchanted` TINYINT(4)  NOT NULL DEFAULT 0;
ALTER TABLE `game`.`Equip_Places` DROP COLUMN `display_order`,
 DROP COLUMN `item_category_id`;

INSERT INTO `Equip_Places` (equip_place_name) values ('Left Ring Finger');
INSERT INTO `Equip_Places` (equip_place_name) values ('Right Ring Finger');
INSERT INTO `Equip_Places` (equip_place_name) values ('Neck');

INSERT INTO `Item_Category` (item_category, hidden, auto_add_to_shop, findable, delete_when_sold_to_shop, always_enchanted)
	values ('Amulet', 0, 1, 1, 0, 1);
INSERT INTO `Item_Category` (item_category, hidden, auto_add_to_shop, findable, delete_when_sold_to_shop, always_enchanted)
	values ('Ring', 0, 1, 1, 0, 1);

set @amulet_cat_id = (select item_category_id FROM Item_Category where item_category = 'Amulet');
set @ring_cat_id = (select item_category_id FROM Item_Category where item_category = 'Ring');

INSERT INTO `Equip_Place_Category` (equip_place_id, item_category_id) 
	values ((select equip_place_id FROM Equip_Places where equip_place_name = 'Left Ring Finger'), @ring_cat_id);
INSERT INTO `Equip_Place_Category` (equip_place_id, item_category_id) 
	values ((select equip_place_id FROM Equip_Places where equip_place_name = 'Right Ring Finger'), @ring_cat_id);
INSERT INTO `Equip_Place_Category` (equip_place_id, item_category_id) 
	values ((select equip_place_id FROM Equip_Places where equip_place_name = 'Neck'), @amulet_cat_id);

INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Amulet', @amulet_cat_id, 100, 10, 1, 0, 'amulet.png');
INSERT INTO `Item_Type` (item_type, item_category_id, base_cost, prevalence, weight, usable, image) values ('Ring', @ring_cat_id, 100, 20, 0.5, 0, 'ring.png');

INSERT INTO `Enchantment_Item_Category`
	SELECT enchantment_id, @amulet_cat_id FROM `Enchantments`
		WHERE enchantment_name IN ('daily_heal', 'extra_turns', 'stat_bonus', 'movement_bonus', 'critical_hit_bonus', 'resistances');

INSERT INTO `Enchantment_Item_Category`
	SELECT enchantment_id, @ring_cat_id FROM `Enchantments`
		WHERE enchantment_name IN ('daily_heal', 'extra_turns', 'stat_bonus', 'movement_bonus', 'critical_hit_bonus', 'resistances');

ALTER TABLE `Skill` ADD COLUMN `base_stats` VARCHAR(100)  NOT NULL;

UPDATE `Skill` set base_stats = 'Intelligence, Divinity' where skill_name = 'Awareness';
UPDATE `Skill` set base_stats = 'Constitution' where skill_name = 'Berserker Rage';
UPDATE `Skill` set base_stats = 'Intelligence' where skill_name = 'Charisma';
UPDATE `Skill` set base_stats = 'Intelligence' where skill_name = 'Fletching';
UPDATE `Skill` set base_stats = 'Divinity' where skill_name = 'Medicine';
UPDATE `Skill` set base_stats = 'Intelligence' where skill_name = 'Metallurgy';
UPDATE `Skill` set base_stats = 'Intelligence' where skill_name = 'Negotiation';
UPDATE `Skill` set base_stats = 'Constitution' where skill_name = 'Recall';
UPDATE `Skill` set base_stats = 'Strength' where skill_name = 'Shield Bash';
UPDATE `Skill` set base_stats = 'Intelligence' where skill_name = 'Strategy';
UPDATE `Skill` set base_stats = 'Intelligence' where skill_name = 'Tactics';
UPDATE `Skill` set base_stats = 'Divinity' where skill_name = 'War Cry';

CREATE TABLE `Global_News` (
  `news_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `day_id` INTEGER  NOT NULL,
  `message` VARCHAR(5000)  NOT NULL,
  PRIMARY KEY (`news_id`),
  INDEX `day_id_idx`(`day_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Kingdom` ADD COLUMN `majesty` INTEGER  NOT NULL DEFAULT 0 AFTER `capital`,
 ADD COLUMN `majesty_leader_since` DATETIME DEFAULT NULL AFTER `majesty`;

ALTER TABLE `Kingdom` ADD COLUMN `has_crown` INTEGER  NOT NULL DEFAULT 0 AFTER `majesty_leader_since`;

ALTER TABLE `Kingdom` ADD COLUMN `majesty_rank` INTEGER  DEFAULT NULL AFTER `majesty`;

ALTER TABLE `Character` ADD COLUMN `has_usable_actions_combat` INTEGER  NOT NULL DEFAULT 0 AFTER `resist_poison_bonus`,
 ADD COLUMN `has_usable_actions_non_combat` INTEGER  NOT NULL DEFAULT 0 AFTER `has_usable_actions_combat`;




