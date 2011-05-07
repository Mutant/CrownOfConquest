UPDATE Party set rank_separator_position = 1 where rank_separator_position <= 0;

update `Character` set creature_group_id = NULL where mayor_of is null and creature_group_id is not null and (status != 'mayor_garrison' or status is null) and party_id is not null;
