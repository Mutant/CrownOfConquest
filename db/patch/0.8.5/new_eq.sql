ALTER TABLE `Item_Type` ADD COLUMN `height` INTEGER  NOT NULL DEFAULT 1,
 ADD COLUMN `width` INTEGER  NOT NULL DEFAULT 1;

UPDATE `Item_Type` set height = 2 where item_type = 'Short Sword';
UPDATE `Item_Type` set height = 3 where item_type = 'Long Sword';
UPDATE `Item_Type` set height = 2, width = 2 where item_type = 'Leather Armour';
UPDATE `Item_Type` set height = 2, width = 2 where item_type = 'Chain Mail';
UPDATE `Item_Type` set height = 2 where item_type = 'Battle Axe';
UPDATE `Item_Type` set height = 2 where item_type = 'Head Scarf';
UPDATE `Item_Type` set height = 2 where item_type = 'Leather Helmet';
UPDATE `Item_Type` set height = 2 where item_type = 'Large Wooden Shield';
UPDATE `Item_Type` set height = 2 where item_type = 'Bronze Head Cap';
UPDATE `Item_Type` set height = 3 where item_type = 'Two-Handed Sword';
UPDATE `Item_Type` set height = 2 where item_type = 'Hand Axe';
UPDATE `Item_Type` set height = 3 where item_type = 'Bastard Sword';
UPDATE `Item_Type` set height = 3 where item_type = 'Spear';
UPDATE `Item_Type` set height = 2, width = 2 where item_type = 'Splint Mail';
UPDATE `Item_Type` set height = 2 where item_type = 'Steel Head Cap';
UPDATE `Item_Type` set height = 2 where item_type = 'Flail';
UPDATE `Item_Type` set height = 2 where item_type = 'Mace';
UPDATE `Item_Type` set height = 3 where item_type = 'Spear';
UPDATE `Item_Type` set height = 3 where item_type = 'Pike';
UPDATE `Item_Type` set height = 2 where item_type = 'Quarterstaff';
UPDATE `Item_Type` set height = 3 where item_type = 'Halberd';
UPDATE `Item_Type` set height = 3 where item_type = 'Broadsword';
UPDATE `Item_Type` set height = 2 where item_type = 'War Hammer';
UPDATE `Item_Type` set height = 3 where item_type = 'Long Bow';
UPDATE `Item_Type` set height = 2, width = 2 where item_type = 'Scale Mail';
UPDATE `Item_Type` set height = 2, width = 2 where item_type = 'Full Plate Mail';
UPDATE `Item_Type` set height = 2 where item_type = 'Medium Steel Shield';
UPDATE `Item_Type` set height = 2, width = 2 where item_type = 'Large Steel Shield';
UPDATE `Item_Type` set height = 2 where item_type = 'Mallet';
UPDATE `Item_Type` set height = 2 where item_type = 'Pickaxe';
UPDATE `Item_Type` set height = 2 where item_type = 'Shovel';

CREATE TABLE `Item_Grid` (
  `item_grid_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `owner_id` INTEGER  NOT NULL,
  `owner_type` VARCHAR(50)  NOT NULL,
  `item_id` INTEGER DEFAULT NULL,
  `x` INTEGER  NOT NULL,
  `y` INTEGER  NOT NULL,
  `start_sector` TINYINT DEFAULT 0,
  PRIMARY KEY (`item_grid_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Equip_Places` ADD COLUMN `height` INTEGER  NOT NULL DEFAULT 1 AFTER `equip_place_name`,
 ADD COLUMN `width` INTEGER  NOT NULL DEFAULT 1 AFTER `height`;
UPDATE `Equip_Places` set height = 2 where equip_place_name = 'Head';
UPDATE `Equip_Places` set height = 2, width = 2 where equip_place_name = 'Torso and Legs';
UPDATE `Equip_Places` set height = 3, width = 2 where equip_place_name = 'Left Hand';
UPDATE `Equip_Places` set height = 3, width = 2 where equip_place_name = 'Right Hand';


ALTER TABLE `Item_Grid` ADD COLUMN `tab` INTEGER  NOT NULL DEFAULT 1 AFTER `item_id`;


