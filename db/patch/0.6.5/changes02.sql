CREATE TABLE `Promo_Code` (
  `code_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(40)  NOT NULL,
  `promo_org_id` INTEGER  NOT NULL,
  `used` TINYINT  NOT NULL DEFAULT 0,
  PRIMARY KEY (`code_id`)
)
ENGINE = InnoDB;

CREATE TABLE `Promo_Org` (
  `promo_org_id` INTEGER  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(200)  NOT NULL,
  `extra_start_turns` INTEGER  NOT NULL,
  PRIMARY KEY (`promo_org_id`)
)
ENGINE = InnoDB;

ALTER TABLE `Player` ADD COLUMN `promo_code_id` INTEGER  DEFAULT NULL AFTER `send_daily_report`;

INSERT into `Promo_Org` (name, extra_start_turns) values ('Betagratis', 100);

INSERT INTO `Promo_Code` (code, promo_org_id) values ('29946eab7c2adfb0bfe0081a2134fbb7', (select promo_org_id from Promo_Org where name = 'Betagratis'));

INSERT INTO `Promo_Code` (code, promo_org_id) values ('12ba79144b6246db433d1d49982cfb53', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('f9ffc8e38cf00a142e723b9fbd9c10b6', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('111379865c8f22ddf4d8442f4d1fa1cd', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('e54c20411f00b56a54581b09beb2fe85', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('e2a64858cf8d3c4241a06dfd3931aa2d', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('72a0421a2617559ff0276497fae4fcd6', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('33d4a3a554432d47d70f464312708f53', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('c91474c8011870090de336e73f3a283f', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('d4322301c3138e1979e0e63c3256f9f8', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('5f48268a0db43ce75c2140abddbce6c7', (select promo_org_id from Promo_Org where name = 'Betagratis'));
INSERT INTO `Promo_Code` (code, promo_org_id) values ('cf7510007e0e7c8b2d23167b698143a6', (select promo_org_id from Promo_Org where name = 'Betagratis'));
