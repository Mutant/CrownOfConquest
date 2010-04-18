package RPG::NewDay::Action::EmailReport;

use Moose;

extends 'RPG::NewDay::Base';

use RPG::Email;

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Party/ };

sub run {
    my $self = shift;
    my $context = $self->context;

    my $party_rs = $context->schema->resultset('Party')->search(
        {
            created => {'!=',undef},
            defunct => undef,
            'player.deleted' => 0,
            'player.send_daily_report' => 1,
        },
        { 
        	prefetch => [
        		'characters', 
        		'player', 
        		{'location' => 'town'}
        	], 
        }
    );
    
    while ( my $party = $party_rs->next ) {
		my $offline_combat_count = 
			$context->schema->resultset('Combat_Log')->get_offline_log_count( $party, $context->yesterday->date_started );
			
		my @combat_logs = 
			$context->schema->resultset('Combat_Log')->get_recent_logs_for_party($party, $offline_combat_count);
			
		my @quests = $context->schema->resultset('Quest')->search(
			{
				party_id => $party->id,
				status => 'In Progress',
			},
			{
				prefetch => 'town',
			}
		);

        my $message = RPG::Template->process(
            $context->config,
            'party/email/daily_report.txt',
            {
                url          => $context->config->{url_root},
                party        => $party,
                offline_combat_count => $offline_combat_count,
                combat_logs => \@combat_logs,
                c => $context,
                quests => \@quests,
                in_town => $party->location->town ? 1 : 0,
            }
        );
        
        RPG::Email->send(
        	$context->config,
        	{
	            players => [$party->player],
	            subject => 'Daily Report',
	            body    => $message,
        	}
        );
    }
}

1;
