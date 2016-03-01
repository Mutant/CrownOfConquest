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
    my $c = $self->context;
    
    my @garrison = $c->schema->resultset('Garrison')->search(
        {
            land_id => {'!=', undef},
            established => {'<=', DateTime->now->subtract( days => 2 )},
        }
    );    
    
    foreach my $garrison (@garrison) {        
        if ($garrison->is_claiming_land) {
            $garrison->claim_land;
        }
        else {
            $garrison->unclaim_land;
        }   
    }
    
}

1;