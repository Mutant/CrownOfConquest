ALTER TABLE `game`.`Town` ADD COLUMN `blacksmith_age` INTEGER  NOT NULL DEFAULT 0 AFTER `prosperity`,
 ADD COLUMN `blacksmith_skill` INTEGER  NOT NULL DEFAULT 0 AFTER `blacksmith_age`;

ALTER TABLE `game`.`Item_Variable` ADD COLUMN `item_variable_name_id` INTEGER  NOT NULL DEFAULT 0;

UPDATE `game`.`Item_Variable` set `item_variable_name_id` = 1;

INSERT INTO `Item_Variable_Name` VALUES (2,'Damage Upgrade',1),(3,'Attack Factor Upgrade',1);

CREATE TABLE `game`.`Item_Property_Category` (
  `property_category_id` integer  NOT NULL AUTO_INCREMENT,
  `category_name` varchar(255)  NOT NULL,
  PRIMARY KEY (`property_category_id`)
)
ENGINE = InnoDB;

ALTER TABLE `game`.`Item_Variable_Name` ADD COLUMN `property_category_id` integer  DEFAULT NULL AFTER `item_category_id`;

ALTER TABLE `game`.`Item_Attribute_Name` ADD COLUMN `property_category_id` integer  DEFAULT NULL AFTER `value_type`;

