update Land set creature_threat = 0;

update Creature_Type set image = 'wispsmall.png' where creature_type = 'Wisp';
update Creature_Type set image = 'wyvernsmall.png' where creature_type = 'Wyvern';
update Creature_Type set image = 'orcgruntsmall.png' where creature_type = 'Orc Grunt';
update Creature_Type set image = 'hobgoblinsmall.png' where creature_type = 'Hobgoblin';
update Creature_Type set image = 'firedragonsmall.png' where creature_type = 'Fire Dragon';
update Creature_Type set image = 'golddragonsmall.png' where creature_type = 'Gold Dragon';
update Creature_Type set image = 'silverdragonsmall.png' where creature_type = 'Silver Dragon';
