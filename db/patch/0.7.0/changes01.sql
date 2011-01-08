INSERT into Spell (spell_name, description, points, class_id, target, combat, non_combat, hidden) 
  values ('Portal', 'Allows the party to return to the wilderness from anywhere in a dungeon', 6, 3, 'party', 0, 1, 0);

UPDATE Land set creature_threat = -60 where creature_threat <= -60;
