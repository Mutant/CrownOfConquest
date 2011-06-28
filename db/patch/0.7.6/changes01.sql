ALTER TABLE `Day_Log` ADD INDEX `party_id_dx`(`party_id`);

ALTER TABLE `Mapped_Sectors` ADD INDEX `land_party_idx`(`land_id`, `party_id`);

