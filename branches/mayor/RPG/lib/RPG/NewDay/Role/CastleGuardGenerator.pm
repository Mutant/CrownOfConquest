package RPG::NewDay::Role::CastleGuardGenerator;

use Moose::Role;
use warnings;
use Carp;

use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Array::Iterator::Circular;

sub generate_guards {
	my $self   = shift;
	my $castle = shift;

	my $c = $self->context;

	my $town = $castle->town;

	return unless $town;

	my $levels_aggregate = $town->prosperity * 15;
	
	my $max_level = int $town->prosperity / 2.5;
	$max_level = 6 if $max_level < 6;

	my @creature_types = $c->schema->resultset('CreatureType')->search(
		{
			'category.name' => 'Guards',
			'level' => {'<=', $max_level},
		},
		{
			join     => 'category',
			order_by => 'level',
		}
	);
	
	my @creatures = $c->schema->resultset('Creature')->search(
		{
			'dungeon_room.dungeon_id' => $castle->id,
		},
		{
			prefetch => 'type',
			join => {'creature_group' => {'dungeon_grid' => 'dungeon_room'}},
		}
	);
	
	foreach my $creature (@creatures) {
		$levels_aggregate -= $creature->type->level;	
	}
	
	$self->context->logger->debug("Generating $levels_aggregate levels of guards in town " . $town->id);

	my $lowest_level = $creature_types[0]->level;
	my $highest_level_type = $creature_types[$#creature_types];
	
	my $room_iterator = Array::Iterator::Circular->new($castle->rooms);	

	while ( $levels_aggregate >= $lowest_level ) {
		
		my $random_sector = $c->schema->resultset('Dungeon_Grid')->find_random_sector( $castle->id, $room_iterator->next->id );

		next if $random_sector->creature_group;

		my $cg = $c->schema->resultset('CreatureGroup')->create(
			{
				creature_group_id => undef,
				dungeon_grid_id   => $random_sector->id,
			}
		);

		my $type = ( shuffle @creature_types )[0];

		my $group_size = Games::Dice::Advanced->roll('2d4');

		for my $count ( 1 .. $group_size ) {
			$cg->add_creature( $type, $count );

			$levels_aggregate -= $type->level;

			last if $levels_aggregate < $type->level;
		}
	}
	
	# See if the mayor has a group (if there is one)
	return unless $castle->town->mayor;
	
	my $mayors_group = $c->schema->resultset('Creature_Group')->find(
		{
			'mayor_of.town_id' => $castle->town->id,
		},
		{
			join => {'characters' => 'mayor_of'},
		}
	);
	
	unless ($mayors_group) {
		my $mayor = $castle->town->mayor_character;
		
		my $sector = $c->schema->resultset('Dungeon_Grid')->find_random_sector( $castle->id, undef, 1 );
		
		$mayors_group = $c->schema->resultset('Creature_Group')->create(
			{
				dungeon_grid_id => $sector->id,
			}						
		);
		
		$mayor->creature_group_id($mayors_group->id);
		$mayor->update;
	}
	
	my $number_of_guards = $mayors_group->creatures->count;
	my $number_to_create = 6 - $number_of_guards;
	
	for my $count ( 1 .. $number_to_create ) {
		$mayors_group->add_creature( $highest_level_type, $count );
	}
	
}

1;
