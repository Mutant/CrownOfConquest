package RPG::NewDay::Action::Sewers;

use Moose;

extends 'RPG::NewDay::Base';
with qw/
  RPG::NewDay::Role::DungeonGenerator
  /;

use RPG::Maths;
use Games::Dice::Advanced;

sub run {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search(
        {},
        {
            join => 'sewer',
        }
    );

    while ( my $town = $town_rs->next ) {
        next if $town->sewer;

        $c->logger->debug( "Creating sewer for town " . $town->id );

        my $dungeon = $c->schema->resultset('Dungeon')->create(
            {
                land_id => $town->land_id,
                type    => 'sewer',
                level   => 1,
                tileset => 'sewer',
            }
        );

        my $floors = RPG::Maths->weighted_random_number( 1 .. 3 );
        my @number_of_rooms;
        for ( 1 .. $floors ) {
            push @number_of_rooms, Games::Dice::Advanced->roll('1d10') + 10;
        }

        $self->generate_dungeon_grid( $dungeon, \@number_of_rooms, 35, 1 );
        $self->generate_treasure_chests( $dungeon, 10 );
        $self->populate_sector_paths($dungeon);
    }
}

1;
