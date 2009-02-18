package RPG::NewDay::Context;

use Mouse;

has 'config'      => ( isa => 'HashRef',          is => 'ro', required => 1 );
has 'schema'      => ( isa => 'RPG::Schema',      is => 'ro', required => 1 );
has 'logger'      => ( isa => 'Log::Dispatch',    is => 'ro', required => 1 );
has 'current_day' => ( isa => 'RPG::Schema::Day', is => 'ro', required => 1 );

1;
