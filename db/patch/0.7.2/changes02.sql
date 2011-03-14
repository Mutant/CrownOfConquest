ALTER TABLE `Building_Type`
 ADD COLUMN `visibility` INT NOT NULL DEFAULT 1 AFTER `labor_to_raze`;

update Building_Type set visibility = level;
