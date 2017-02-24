ALTER TABLE `Map_Tileset` ADD COLUMN `allows_towns` INTEGER DEFAULT 1;
UPDATE Map_Tileset SET allows_towns = 0 WHERE name = 'Snow Fading Bottom';
