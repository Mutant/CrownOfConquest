ALTER TABLE `Quest` ADD COLUMN `days_to_complete` INTEGER  NOT NULL DEFAULT 0 AFTER `status`;

DELETE FROM `Quest` WHERE party_id is null AND status = 'Not Started' and days_to_complete = 0;

CREATE TABLE `Party_Town` (
    party_id       INT NOT NULL,
    town_id        INT NOT NULL,
    tax_amount_paid_today INT NOT NULL DEFAULT 0,
PRIMARY KEY (party_id,town_id)) TYPE=INNODB;