use strict;
use warnings;

package RPG::NewDay;

use RPG::Schema;
use YAML;
use DateTime;

use RPG::NewDay::Shop;
use RPG::NewDay::Party;
use RPG::NewDay::Quest;

sub run {
	my $package = shift;
	
	my $config = YAML::LoadFile('../rpg.yml');
	
	my $schema = RPG::Schema->connect(
		$config,
		$config->{datasource},
        $config->{username},
        $config->{password},
		{AutoCommit => 0},
	);
	
	# Create a new day
	my $yesterday = $schema->resultset('Day')->find(
		{}, 
		{ 
			'select' => { max => 'day_number' }, 
			'as' => 'day_number'
		},
	)->day_number || 1;
	
	my $new_day = $schema->resultset('Day')->create(
		{
			'day_number' => $yesterday+1,
			'game_year' => 100, # TODO: generate game year as well
			'date_started' => DateTime->now(),
		},
	);
		
	# New day for Party
	RPG::NewDay::Party->run($config, $schema, $new_day);

	$schema->storage->dbh->commit;

	# Run shops update
	RPG::NewDay::Shop->run($config, $schema, $new_day);

	$schema->storage->dbh->commit;

	# Add quests to towns
	RPG::NewDay::Quest->run($config, $schema, $new_day);
	
	$schema->storage->dbh->commit;

}

1;