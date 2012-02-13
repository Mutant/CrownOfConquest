package RPG::NewDay::Action::Combat_Log_Archive;
use Moose;

extends 'RPG::NewDay::Base';

sub cron_string {
    my $self = shift;
     
    return $self->context->config->{combat_log_archive_cron_string};   
}

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my @parties = $c->schema->resultset('Party')->search;
    
    foreach my $party (@parties) {
        my $rs = $c->schema->resultset('Combat_Log')->get_old_logs_for_group($party, 500);   
        
        my $count = $rs->count;
        
        next unless $count > 0;
        
        $c->logger->debug("Deleting $count combat logs for party " . $party->id);
        my @recs = $rs->all;
        foreach my $rec (@recs) {
            $rec->delete;   
        }
    }
}

1;
