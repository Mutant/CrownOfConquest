package RPG::NewDay::Action::Castles;

use Moose;

extends 'RPG::NewDay::Base';
with qw/
	RPG::NewDay::Role::DungeonGenerator
	RPG::NewDay::Role::CastleGuardGenerator
/;

use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Data::Dumper;

sub depends { qw/RPG::NewDay::Action::Town RPG::NewDay::Action::Mayor/ }

sub run {
	my $self = shift;
	
	my $c = $self->context;
	
	my $town_rs = $c->schema->resultset('Town')->search(
		{},
		{
			prefetch => 'castle',
		}
	);
	
	while (my $town = $town_rs->next) {
		my $level = int ($town->prosperity / 20);
		$level = 4 if $level > 4;
		$level = 1 if $level < 1;

		if (my $castle = $town->castle) {
			$self->fill_chests($castle);
			$castle->level($level);
			$castle->update;
			next;
		}
		
		$c->logger->debug("Creating castle for town " . $town->id);
		
		my $dungeon = $c->schema->resultset('Dungeon')->create(
            {
                land_id => $town->land_id,
                type => 'castle',
                level => $level,
            }
        );	
        
        my $size = 5 + (int $town->prosperity / 10);
        
        $self->generate_dungeon_grid($dungeon, $size, 0);
        $self->populate_sector_paths($dungeon);
        my @chests = $self->generate_chests($dungeon);
        $self->fill_chests($dungeon, @chests);
        $self->generate_guards($dungeon);
	}
}

sub generate_chests {
	my $self = shift;
	my $dungeon = shift;
	
	my $room;
	foreach my $room_to_check (shuffle $dungeon->rooms) {
		$room = $room_to_check;
		
		# Don't use room with the stairs
		my $sector = $room_to_check->search_related('sectors',
			{
				'stairs_up' => 1,
			}
		);
		next if $sector;
		
		if ($room_to_check->sectors->count > 10) {
			last;	
		}
	}
	
	my @sectors = $room->sectors;
	my $chest_count = 2 + Games::Dice::Advanced->roll('1d3');
	$chest_count = scalar @sectors if $chest_count > scalar @sectors;
	
	$self->context->logger->debug("Generating $chest_count chests in castle " . $dungeon->id);
	
	my @chests;
	foreach my $sector (@sectors) {
		next if $sector->has_door && scalar @sectors != 1;
		
		my $chest = $self->context->schema->resultset('Treasure_Chest')->create(
			{
				dungeon_grid_id => $sector->id,
			}
		);
		
		push @chests, $chest;
		
		$chest_count--;
		last if $chest_count == 0;
	}
	
	return @chests;
}

sub fill_chests {
	my $self = shift;
	my $dungeon = shift;
	my @chests = @_;
	
	unless (@chests) {
		@chests = $dungeon->treasure_chests;		
		
		@chests = $self->generate_chests($dungeon) unless @chests;
	}
		
	my $gold = $dungeon->town->prosperity * 25 + Games::Dice::Advanced->roll('1d500');
	
	foreach my $chest (@chests) {
		$chest->gold(int ($gold / scalar @chests));
		$chest->add_trap;
		$chest->update; 
	}
	
	
}

__PACKAGE__->meta->make_immutable;

1;