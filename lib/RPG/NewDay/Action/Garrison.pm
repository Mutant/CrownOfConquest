package RPG::NewDay::Action::Garrison;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;

sub cron_string {
    my $self = shift;

    return $self->context->config->{garrison_cron_string};
}

sub run {
    my $self = shift;
    my $c    = $self->context;


    my $dt  = DateTime->now->subtract( days => 2 );
    my $fdt = $c->schema->storage->datetime_parser->format_datetime($dt);

    my @garrison = $c->schema->resultset('Garrison')->search(
        {
            land_id => { '!=', undef },
            established => { '<=', $fdt },
        }
    );

    foreach my $garrison (@garrison) {
        if ( $garrison->is_claiming_land ) {
            $garrison->claim_land;
        }
        else {
            $garrison->unclaim_land;
        }
    }

}

1;
