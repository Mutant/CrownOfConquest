package RPG::Exception;

use Moose;

has 'message' => ( isa => 'Str', is => 'ro', required => 1 );
has 'type'    => ( isa => 'Str', is => 'ro', required => 0 );

1;
