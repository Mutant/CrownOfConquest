use strict;
use warnings;

package RPG::NewDay;

use RPG::Schema;
use YAML;
use DateTime;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;

use RPG::NewDay::Shop;
use RPG::NewDay::Party;
use RPG::NewDay::Quest;

sub run {
	my $package = shift;
	
	my $config = YAML::LoadFile('../rpg.yml');
	if (-f '../rpg_local.yml') {
		my $local_config = YAML::LoadFile('../rpg_local.yml');
		$config = {%$config, %$local_config};
	}
	
	my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . '] ' . $_[1]."\n" } );
	$logger->add( 
		Log::Dispatch::File::Stamped->new( 
			name => 'file1',
			min_level => 'debug',
			filename => $config->{log_file_dir} . 'new_day.log',
			mode => 'append',
			stamp_fmt => '%Y%m%d',
		), 
	);
	
	eval {
		do_new_day($config, $logger);
	};
	if ($@) {
		$logger->error("Error running new day script: $@");	
	}
	
}

sub do_new_day {
	my ($config, $logger) = @_;
	
	my $schema = RPG::Schema->connect(
		$config,
		@{ $config->{'Model::DBIC'}{connect_info} },
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
	
	$logger->info("Beginning new day script for day: " . $new_day->day_number);
		
	# New day for Party
	RPG::NewDay::Party->run($config, $schema, $logger, $new_day);

	# Run shops update
	RPG::NewDay::Shop->run($config, $schema, $logger, $new_day);

	# Add quests to towns
	RPG::NewDay::Quest->run($config, $schema, $logger, $new_day);
	
	$schema->storage->dbh->commit;
	
	$logger->info("Successfully completed new day script for day: " . $new_day->day_number);

}

1;