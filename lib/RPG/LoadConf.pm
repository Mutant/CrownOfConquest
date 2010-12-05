package RPG::LoadConf;

# Used for non-catalyst things that need to load the conf.

use strict;
use warnings;

use YAML;

sub load {
	my $package = shift;
	
	my $home = $ENV{RPG_HOME};
	
	my $config = YAML::LoadFile("$home/rpg.yml");
	my $suffix = $ENV{CATALYST_CONFIG_LOCAL_SUFFIX} // 'local';	
	if ( -f "$home/rpg_$suffix.yml" ) {		
		my $local_config = YAML::LoadFile("$home/rpg_$suffix.yml");
		$config = { %$config, %$local_config };
	}
	
	return $config;
}

1;