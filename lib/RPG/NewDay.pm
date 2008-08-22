use strict;
use warnings;

package RPG::NewDay;

use RPG::Schema;
use YAML;
use DateTime;

use RPG::NewDay::Shop;
use RPG::NewDay::Party;

sub run {
	my $package = shift;
	
	my $config = YAML::LoadFile('../rpg.yml');
	
	my $schema = RPG::Schema->connect(
		$config,
		$config->{datasource},
        $config->{username},
        $config->{password},
		{AutoCommit => 1},
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

	# Run shops update
	RPG::NewDay::Shop->run($config, $schema, $new_day);

}

1;