package RPG::NewDay::Context;

use Moose;

use RPG::Ticker::LandGrid;

has 'config'      => ( isa => 'HashRef',               is => 'ro', required => 1 );
has 'schema'      => ( isa => 'RPG::Schema',           is => 'ro', required => 1 );
has 'logger'      => ( isa => 'Log::Dispatch',         is => 'ro', required => 1 );
has 'current_day' => ( isa => 'RPG::Schema::Day',      is => 'rw', required => 0 );
has 'yesterday'   => ( isa => 'RPG::Schema::Day',      is => 'rw', required => 0 );
has 'datetime'    => ( isa => 'DateTime',              is => 'ro', required => 1 );
has 'land_grid'   => ( isa => 'RPG::Ticker::LandGrid', is => 'ro', required => 0, lazy => 1, builder => '_build_land_grid' );

sub _build_land_grid {
    my $self = shift;
    
    return RPG::Ticker::LandGrid->new( schema => $self->schema );
}

__PACKAGE__->meta->make_immutable;


1;
