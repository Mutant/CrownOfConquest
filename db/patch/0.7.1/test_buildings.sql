INSERT INTO `Building` (land_id, building_type_id, owner_id, owner_type,
 name, clay_needed, stone_needed, wood_needed, iron_needed, labor_needed)
 VALUES (72508, (select building_type_id from Building_Type where name = 'Fort'),
 125, 'garrison', 'Fort', 2, 2, 2, 2, 5);

INSERT INTO `Building` (land_id, building_type_id, owner_id, owner_type,
 name, clay_needed, stone_needed, wood_needed, iron_needed, labor_needed)
 VALUES (72508, (select building_type_id from Building_Type where name = 'Armory2'),
 125, 'garrison', 'Our Armory2', 2, 2, 2, 2, 5);

