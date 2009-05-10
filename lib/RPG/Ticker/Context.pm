package RPG::Ticker::Context;

use Moose;
has 'config'       => ( isa => 'HashRef',                  is => 'ro', required => 1 );
has 'schema'       => ( isa => 'RPG::Schema',              is => 'ro', required => 1 );
has 'logger'       => ( isa => 'Log::Dispatch',            is => 'ro', required => 1 );
has 'land_grid'    => ( isa => 'RPG::Ticker::LandGrid',    is => 'ro', required => 1 );
#has 'dungeon_grid' => ( isa => 'RPG::Ticker::DungeonGrid', is => 'ro', required => 1 );

1;
