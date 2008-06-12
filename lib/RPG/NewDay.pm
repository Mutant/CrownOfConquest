use strict;
use warnings;

package RPG::NewDay;

use RPG::Schema;
use YAML;

use RPG::NewDay::Shop;
use RPG::NewDay::Party;

sub run {
	my $package = shift;
	
	my $config = YAML::LoadFile('../rpg.yml');
	
	my $schema = RPG::Schema->connect(
		$config->{datasource},
        $config->{username},
        $config->{password},
		{AutoCommit => 1},
	);
	
	# Run shops update
	RPG::NewDay::Shop->run($config, $schema);
	
	# New day for Party
	RPG::NewDay::Party->run($config, $schema);
}

1;