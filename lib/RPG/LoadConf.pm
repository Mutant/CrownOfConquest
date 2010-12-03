package RPG::LoadConf;

# Used for non-catalyst things that need to load the conf.

use strict;
use warnings;

use YAML;

sub load {
	my $package = shift;
	
	my $home = $ENV{RPG_HOME};
	
	my $config = YAML::LoadFile("$home/rpg.yml");
	if ( -f "$home/rpg_local.yml" ) {
		my $suffix = $ENV{CATALYST_CONFIG_LOCAL_SUFFIX} // 'local';
		my $local_config = YAML::LoadFile("$home/rpg_$suffix.yml");
		$config = { %$config, %$local_config };
	}
	
	return $config;
}

1;