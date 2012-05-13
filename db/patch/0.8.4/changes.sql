ALTER TABLE `Items` ADD UNIQUE INDEX `unique_equip_slot`(`character_id`, `equip_place_id`);

