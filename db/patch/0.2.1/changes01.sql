ALTER TABLE `game`.`Town` ADD COLUMN `blacksmith_age` INTEGER  NOT NULL DEFAULT 0 AFTER `prosperity`,
 ADD COLUMN `blacksmith_skill` INTEGER  NOT NULL DEFAULT 0 AFTER `blacksmith_age`;

ALTER TABLE `game`.`Item_Variable` ADD COLUMN `item_variable_name_id` INTEGER  NOT NULL DEFAULT 0;

UPDATE `game`.`Item_Variable` set `item_variable_name_id` = 1;

CREATE TABLE `game`.`Item_Property_Category` (
  `property_category_id` integer  NOT NULL AUTO_INCREMENT,
  `category_name` varchar(255)  NOT NULL,
  PRIMARY KEY (`property_category_id`)
)
ENGINE = InnoDB;

ALTER TABLE `game`.`Item_Variable_Name` ADD COLUMN `property_category_id` integer  DEFAULT NULL AFTER `item_category_id`;

ALTER TABLE `game`.`Item_Attribute_Name` ADD COLUMN `property_category_id` integer  DEFAULT NULL AFTER `value_type`;

ALTER TABLE `game`.`Item_Variable_Name` ADD COLUMN `create_on_insert` TINYINT  NOT NULL DEFAULT 1 AFTER `property_category_id`;

INSERT INTO `Item_Property_Category` VALUES (1,'Upgrade'),(2,'Durability');

INSERT INTO `Item_Variable_Name` VALUES (2,'Damage Upgrade',1,1,0),(3,'Attack Factor Upgrade',1,1,0),(4,'Defence Factor Upgrade',2,1,0),(5,'Attack Factor Upgrade',6,1,0),(6,'Damage Upgrade',6,1,0),(7,'Durability',1,2,1),(8,'Durability',2,2,1),(9,'Durability',6,2,1);

INSERT INTO `Item_Variable_Params` VALUES (4,0,0,0,23,2),(5,0,0,0,23,3),(6,1,80,100,23,7),(7,0,0,0,9,2),(8,0,0,0,9,3),(9,1,80,100,9,7),(10,0,0,0,32,2),(11,0,0,0,32,3),(12,1,60,85,32,7),(13,0,0,0,12,2),(14,0,0,0,12,3),(15,1,100,120,12,7),(16,0,0,0,27,2),(17,0,0,0,27,3),(18,1,60,60,27,7),(19,0,0,0,31,2),(20,0,0,0,31,3),(21,1,90,90,31,7),(22,0,0,0,20,2),(23,0,0,0,20,3),(24,1,70,70,20,7),(25,0,0,0,2,2),(26,0,0,0,2,3),(27,1,100,100,2,7),(28,0,0,0,28,2),(29,0,0,0,28,3),(30,1,50,50,28,7),(31,0,0,0,29,2),(32,0,0,0,29,3),(33,1,80,80,29,7),(34,0,0,0,30,2),(35,0,0,0,30,3),(36,1,50,100,30,7),(37,0,0,0,1,2),(38,0,0,0,1,3),(39,1,70,70,1,7),(40,0,0,0,24,2),(41,0,0,0,24,3),(42,1,80,80,24,7),(43,0,0,0,19,2),(44,0,0,0,19,3),(45,1,90,100,19,7),(46,0,0,0,33,2),(47,0,0,0,33,3),(48,1,70,80,33,7),(49,0,0,0,34,5),(50,0,0,0,34,6),(51,1,100,130,34,9),(52,0,0,0,8,5),(53,0,0,0,8,6),(54,1,90,140,8,9),(55,0,0,0,14,5),(56,0,0,0,14,6),(57,1,40,70,14,9),(58,0,0,0,21,5),(59,0,0,0,21,6),(60,1,60,120,21,9),(61,0,0,0,4,4),(62,1,140,200,4,8),(63,0,0,0,36,4),(64,1,160,240,36,8),(65,0,0,0,3,4),(66,1,60,130,3,8),(67,0,0,0,35,4),(68,1,80,190,35,8),(69,0,0,0,25,4),(70,1,80,170,25,8);
