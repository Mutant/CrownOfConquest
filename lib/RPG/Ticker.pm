use strict;
use warnings;

package RPG::Ticker;

use RPG::Schema;
use RPG::Map;

use YAML;
use Data::Dumper;
use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;

sub run {
	my $package = shift;
	
	my $home = $ENV{RPG_HOME};
	
	my $config = YAML::LoadFile("$home/rpg.yml");
	if (-f "$home/rpg_local.yml") {
		my $local_config = YAML::LoadFile("$home/rpg_local.yml");
		$config = {%$config, %$local_config};
	}
		
	my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . '] ' . $_[1]."\n" } );
	$logger->add( 
		Log::Dispatch::File::Stamped->new( 
			name => 'file1',
			min_level => 'debug',
			filename => $config->{log_file_dir} . 'ticker.log',
			mode => 'append',
			stamp_fmt => '%Y%m%d',
		), 
	);
	
	$logger->info('Ticker script beginning');
	
	eval {
		my $schema = RPG::Schema->connect(
			$config,
			@{ $config->{'Model::DBIC'}{connect_info} },
		);
		
		# Clean up
		$package->clean_up($config, $schema, $logger);
		
		# Spawn monsters
		$package->spawn_monsters($config, $schema, $logger);
		
		# Move monsters
		$package->move_monsters($config, $schema, $logger);
		
		$schema->storage->dbh->commit unless $schema->storage->dbh->{AutoCommit};
	};
	if ($@) {
		$logger->error("Error running ticker script: $@");	
	}
	
	$logger->info('Ticker script ended');
}

sub spawn_monsters {
	my ($package, $config, $schema, $logger) = @_;
	
	my $number_of_groups_to_spawn = $package->_calculate_number_of_groups_to_spawn($config, $schema);
	
	$logger->info("Spawning $number_of_groups_to_spawn monsters");
	
	return if $number_of_groups_to_spawn <= 0;

	my @creature_types = $schema->resultset('CreatureType')->search();
	
	my %x_y_range = $schema->resultset('Land')->get_x_y_range();
	
	# Spawn random groups
	for (1..$number_of_groups_to_spawn) {
		my $land = $package->_find_land_to_create_cg(
			$schema,
			$x_y_range{max_x},
			$x_y_range{max_y},
		);
	
		my $cg = $schema->resultset('CreatureGroup')->create({
			land_id => $land->id,
		});
		
		my $number = int (rand 7) + 3;
		
		my $max_level = (int $land->creature_threat / 10) + 1;
		#warn "CTR: " . $land->creature_threat;
		#warn "max level : $max_level\n";
		
		my $type;
		foreach my $type_to_check (shuffle @creature_types) {
			next if $type_to_check->level > $max_level;
			$type = $type_to_check;
			last;
		}	
			
		for my $creature (1 .. $number) {			
			my $hps = Games::Dice::Advanced->roll($type->level . 'd8');
			
			$schema->resultset('Creature')->create({
				creature_type_id => $type->id,
				creature_group_id => $cg->id,
				hit_points_current => $hps,
				hit_points_max => $hps,
				group_order => $creature,
			});
		}
	}
}

sub _calculate_number_of_groups_to_spawn {
	my ($package, $config, $schema) = @_;
	
	# Calculate how many creature groups we should spawn
	my $number_of_parties = $schema->resultset('Party')->search->count;
	
	my $number_of_creature_groups = $schema->resultset('CreatureGroup')->search->count;
	
	my $size_of_world = $schema->resultset('Land')->search->count;
	
	my $ideal_groups = $number_of_parties * $config->{creature_groups_to_parties};
	
	if ($ideal_groups > $size_of_world * $config->{max_creature_groups_per_sector}) {
		$ideal_groups = $size_of_world * $config->{max_creature_groups_per_sector};
	}
	elsif ($ideal_groups < $size_of_world * $config->{min_creature_groups_per_sector}) {
		$ideal_groups = $size_of_world * $config->{min_creature_groups_per_sector};
	}
	
	# We don't remove groups if we're over the max
	my $number_of_groups_to_spawn = 0;
	if ($ideal_groups > $number_of_creature_groups) {
		$number_of_groups_to_spawn = $ideal_groups - $number_of_creature_groups;	
	}
	
	#warn "Spawning: $number_of_groups_to_spawn\n";	
	
	return $number_of_groups_to_spawn;
}

sub _find_land_to_create_cg {
	my ($package, $schema, $max_x, $max_y) = @_;
	
	my %cords;	
	my $land;
	while (! %cords) {
		%cords = (
			x => int (rand $max_x) + 1,
			y => int (rand $max_y) + 1,
		);
		
		#warn Dumper \%cords;

		($land) = $schema->resultset('Land')->search(
			{
				x => $cords{x},
				y => $cords{y}				
			},
			{
				prefetch => 'terrain',
			},
		);
		
		undef %cords, next if $land->terrain->terrain_name eq 'town'; 
	
		my $already_cg = $schema->resultset('CreatureGroup')->search(
			land_id => $land->id,
		)->count;
		
		undef %cords unless $already_cg == 0;	
	}
	
	return $land;
}

sub move_monsters {
	my ($package, $config, $schema, $logger) = @_;
	
	my $cg_rs = $schema->resultset('CreatureGroup')->search(
		{
			'location.land_id' => {'!=', undef},
		},
		{
			prefetch => ['location', 'in_combat_with'],
		},
	);
	
	my %x_y_range = $schema->resultset('Land')->get_x_y_range();

	my $moved = 0;
	while (my $cg = $cg_rs->next) {
		next if $cg->in_combat_with;
		
		next unless Games::Dice::Advanced->roll('1d100') > $config->{creature_move_chance};
		
		$moved++;
		
		# Find sector to move to		
		my @adjacent_sectors = RPG::Map->get_adjacent_sectors(
			$cg->location->x,
			$cg->location->y,
			$x_y_range{min_x},
			$x_y_range{min_y},
			$x_y_range{max_x},
			$x_y_range{max_y},
		);
		@adjacent_sectors = shuffle @adjacent_sectors;

		foreach my $sector (@adjacent_sectors) {
			my $land = $schema->resultset('Land')->find(
				{
					x => $sector->[0],
					y => $sector->[1],
				},
				{
					prefetch => ['town', 'creature_group'],
				},
			);
			
			# Can't move to a town or sector that already has a creature group
			unless ($land->town || $land->creature_group) {
				$cg->land_id($land->id);
				$cg->update;
				#warn "Moving group " . $cg->id . " to " . $sector->[0] . "," . $sector->[1] . "\n";
				last;	
			}
		}		
	}
	
	$logger->info("Moved $moved groups");
}

# Clean up any dead monster groups. These sometimes get created due to bugs
# In an ideal world (or at least one with transactions) this wouldn't be needed.
# We don't delete them, since the news needs to display them
sub clean_up {
    my ($package, $config, $schema, $logger) = @_;
    
    my $cg_rs = $schema->resultset('CreatureGroup')->search();
        
    while (my $cg = $cg_rs->next) {
        if ($cg->number_alive <= 0) {
            $cg->land_id(undef);
            $cg->update;            
        }
    }
}

1;