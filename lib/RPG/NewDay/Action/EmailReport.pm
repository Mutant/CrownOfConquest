package RPG::NewDay::Action::EmailReport;

use Moose;

extends 'RPG::NewDay::Base';

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Party/ };

sub run {
    my $self = shift;
    my $context = $self->context;

    my $party_rs = $context->schema->resultset('Party')->search(
        {
            created => {'!=',undef},
            defunct => undef,
            'player.deleted' => 0,
        },
        { 
        	prefetch => ['characters', 'player'], 
        }
    );
    
    while ( my $party = $party_rs->next ) {
		my $offline_combat_count = 
			$context->schema->resultset('Combat_Log')->get_offline_log_count( $party, $context->yesterday->date_started );
			
		my @combat_logs = 
			$context->schema->resultset('Combat_Log')->get_recent_logs_for_party($party, $offline_combat_count);

        my $message = RPG::Template->process(
            $context->config,
            'party/email/daily_report.txt',
            {
                url          => $context->config->{url_root},
                party        => $party,
                offline_combat_count => $offline_combat_count,
                combat_logs => \@combat_logs,
                c => $context,
            }
        );
        
        warn $message;

        my $msg = MIME::Lite->new(
            From    => $context->config->{send_email_from},
            To      => $party->player->email,
            Subject => 'Kingdoms - Daily Report',
            Data    => $message,
        );
        #$msg->send( 'smtp', $context->config->{smtp_server}, Debug => 0, );
    }    
}

1;
