ALTER TABLE `Quest` ADD COLUMN `days_to_complete` INTEGER  NOT NULL DEFAULT 0 AFTER `status`;

DELETE FROM `Quest` WHERE party_id is null AND status = 'Not Started' and days_to_complete = 0;