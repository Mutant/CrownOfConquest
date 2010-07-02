update Land set creature_threat = -100 where creature_threat < -100;
update Land set creature_threat = 100 where creature_threat > 100;
