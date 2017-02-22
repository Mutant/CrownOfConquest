package RPG::NewDay::Action::MiniMap;

use Moose;

extends 'RPG::NewDay::Base';

use RPG::Template;
use GD::Simple;
use File::Slurp;
use JSON;
use Carp;

sub cron_string {
    my $self = shift;

    return $self->context->config->{mini_map_cron_string};
}

sub run {
    my $self = shift;

    my $c = $self->context;

    my $land_rs = $c->schema->resultset('Land')->search(
        {},
        {
            prefetch => 'kingdom',
            order_by => [ 'y', 'x' ],
        }
    );

    $land_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $img = GD::Simple->new( 200, 200 );
    my $grid;

    while ( my $land = $land_rs->next ) {
        $img->fgcolor( $land->{kingdom}{colour} );
        $img->rectangle( $land->{x} * 2 - 1, $land->{y} * 2 - 1, $land->{x} * 2, $land->{y} * 2 );

        $grid->[ $land->{x} ][ $land->{y} ] = $land->{kingdom} ? $land->{kingdom}{name} : undef;
    }

    mkdir( $c->config->{home} . '/docroot/static/minimap/' );

    open my $fh, '>', $c->config->{home} . '/docroot/static/minimap/kingdoms.png'
      || croak "Can't open kingdom minimap file for writing";
    binmode $fh;
    print $fh $img->png;
    close $fh;

    write_file( $c->config->{data_file_path} . 'kingdoms.json', to_json($grid) );
}

1;
