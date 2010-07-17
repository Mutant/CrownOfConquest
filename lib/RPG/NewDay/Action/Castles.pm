package RPG::NewDay::Action::Castles;

use Moose;

extends 'RPG::NewDay::Base';
with qw/
	RPG::NewDay::Role::DungeonGenerator
	RPG::NewDay::Role::CastleGuardGenerator
/;

sub depends { qw/RPG::NewDay::Action::Town/ }

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
		next if $town->castle;
		
		$c->logger->debug("Creating castle for town " . $town->id);
		
		my $dungeon = $c->schema->resultset('Dungeon')->find_or_create(
            {
                land_id => $town->land_id,
                type => 'castle',
            }
        );	
        
        my $size = 5 + (int $town->prosperity / 10);
        
        $self->generate_dungeon_grid($dungeon, $size, 0);
        $self->populate_sector_paths($dungeon);
        $self->generate_guards($dungeon);
	}
}

__PACKAGE__->meta->make_immutable;

1;