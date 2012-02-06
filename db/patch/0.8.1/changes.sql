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

CREATE TABLE `Building_Upgrade_Type` (
  `type_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(40)  NOT NULL,
  `modifier_per_level` INTEGER  NOT NULL,
  `modifier_label` VARCHAR(20),
  `description` VARCHAR(2000)  NOT NULL;
  `base_gold_cost` INTEGER  NOT NULL,
  `base_wood_cost` INTEGER  NOT NULL,
  `base_clay_cost` INTEGER  NOT NULL,
  `base_iron_cost` INTEGER  NOT NULL,
  `base_stone_cost` INTEGER  NOT NULL,
  `base_turn_cost` INTEGER  NOT NULL,
  PRIMARY KEY (`type_id`)
)
ENGINE = InnoDB;

CREATE TABLE `Building_Upgrade` (
  `upgrade_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `building_id` INTEGER  NOT NULL,
  `type_id` INTEGER  NOT NULL,
  `level` INTEGER  NOT NULL DEFAULT 0,
  PRIMARY KEY (`upgrade_id`),
  INDEX `building_id_idx`(`building_id`),
  INDEX `type_id_idx`(`type_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Building_Type` DROP COLUMN `attack_factor`,
 DROP COLUMN `heal_factor`,
 ADD COLUMN `max_upgrade_level` INTEGER  NOT NULL DEFAULT 0;

UPDATE `Building_Type` set max_upgrade_level = 3 where name = 'Tower';
UPDATE `Building_Type` set max_upgrade_level = 6 where name = 'Fort';
UPDATE `Building_Type` set max_upgrade_level = 10 where name = 'Castle';

INSERT INTO `Building_Upgrade_Type` VALUES (1,'Market',0,0,NULL,'Accumulates gold on a daily basis, which goes to the owner of the building',6,4,2,2,5),(2,'Barracks',0,0,NULL,'Characters within the building can train here, and earn experience',8,3,4,4,5),(3,'Rune of Protection',1000,3,'Resistances','Protects the inhabitants of the building from magical attacks (Fire, Ice and Poison)',0,0,0,0,5),(4,'Rune of Defence',1000,3,'DF','Gives the inhabitants of the building a defensive bonus during combat',0,0,0,0,5),(5,'Rune of Attack',1000,3,'AF','Gives the inhabitants of the building a bonus to attack during combat',0,0,0,0,5);

ALTER TABLE `Party_Messages` ADD COLUMN `sender_id` INTEGER  DEFAULT NULL;
ALTER TABLE `Party_Messages` ADD COLUMN `type` VARCHAR(20)  NOT NULL DEFAULT 'standard';
ALTER TABLE `Party_Messages` ADD COLUMN `subject` VARCHAR(1000);

CREATE TABLE  `game`.`Party_Messages_Recipients` (
  `party_id` int(11) NOT NULL,
  `message_id` int(11) NOT NULL,
  `has_read` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`party_id`,`message_id`)
) ENGINE=InnoDB;



