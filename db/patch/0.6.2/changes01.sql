CREATE  TABLE IF NOT EXISTS `Enchantments` (
  `enchantment_id` INT NOT NULL AUTO_INCREMENT ,
  `enchantment_name` VARCHAR(100) NOT NULL ,
  `must_be_equipped` TINYINT NOT NULL DEFAULT '0',
  PRIMARY KEY (`enchantment_id`) )
ENGINE = InnoDB;

CREATE  TABLE IF NOT EXISTS `Item_Enchantments` (
  `item_enchantment_id` INT NOT NULL AUTO_INCREMENT ,
  `enchantment_id` INT NOT NULL ,
  `item_id` INT(11) NOT NULL ,
  PRIMARY KEY (`item_enchantment_id`) ,
  INDEX `fk_Enchantments_has_Items_Enchantments1` (`enchantment_id` ASC) ,
  INDEX `fk_Enchantments_has_Items_Items1` (`item_id` ASC) )
ENGINE = InnoDB;

ALTER TABLE `Item_Variable` MODIFY COLUMN `item_variable_name_id` INTEGER  DEFAULT NULL,
 ADD COLUMN `item_enchantment_id` INTEGER  AFTER `item_variable_name_id`,
 ADD COLUMN `name` VARCHAR(100)  AFTER `item_enchantment_id`;
ALTER TABLE `Item_Variable` MODIFY COLUMN `item_variable_value` VARCHAR(100)  NOT NULL;

ALTER TABLE `Enchantments` ADD COLUMN `one_per_item` TINYINT(4)  NOT NULL DEFAULT 0 AFTER `must_be_equipped`;

INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('spell_casts_per_day',0);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('indestructible',1);
INSERT INTO `Enchantments` (enchantment_name, one_per_item) values ('magical_damage',1);

CREATE  TABLE IF NOT EXISTS `Enchantment_Item_Category` (
  `enchantment_id` INT NOT NULL,
  `item_category_id` INT NOT NULL,
  PRIMARY KEY (`enchantment_id`,`item_category_id`) )
ENGINE = InnoDB;



