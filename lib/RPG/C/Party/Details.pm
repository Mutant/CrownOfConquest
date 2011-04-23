package RPG::C::Party::Details;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use feature "switch";

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details.html',
                params   => {
                    party   => $c->stash->{party},
                    tab     => $c->req->param('tab') || '',
                    message => $c->flash->{messages},
                    error => $c->flash->{error},
                },
            }
        ]
    );
}

sub history : Local {
    my ( $self, $c ) = @_;

    # Check if new day message should be displayed
    my @day_logs = $c->model('DBIC::DayLog')->search(
        { 
        	'party_id' => $c->stash->{party}->id,
        	'day.day_number' => {'>=', $c->stash->{today}->day_number - 7}, 
        },
        {
            order_by => 'day.date_started desc, day_log_id',
            prefetch => 'day',
        },
    );
    my %day_logs;
    foreach my $message (@day_logs) {
        push @{ $day_logs{ $message->day->day_number } }, $message->log;
    }    

    my @messages = $c->model('DBIC::Party_Messages')->search(
        { 
        	'party_id' => $c->stash->{party}->id,
        	'day.day_number' => {'>=', $c->stash->{today}->day_number - 7}, 
        },
        {
            order_by => 'day.date_started desc',
            prefetch => 'day',
        },
    );

    my %message_logs;
    foreach my $message (@messages) {
        push @{ $message_logs{ $message->day->day_number } }, $message->message;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/history.html',
                params   => {
                    day_logs       => \%day_logs,
                    message_logs   => \%message_logs,
                    today          => $c->stash->{today},
                    history_length => 7,
                },
            }
        ]
    );
}

sub combat_log : Local {
    my ( $self, $c ) = @_;

    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_party( $c->stash->{party}, 20 );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/combat_log.html',
                params   => {
                    logs  => \@logs,
                    party => $c->stash->{party},
                },
            }
        ]
    );
}

sub combat_messages : Local {
    my ( $self, $c ) = @_;
    
    my $combat_log = $c->model('DBIC::Combat_Log')->find($c->req->param('combat_log_id'));
    
    my $opp_num = $c->req->param('opp_num');
    
    my $type = $combat_log->get_column("opponent_${opp_num}_type");
    my $id = $combat_log->get_column("opponent_${opp_num}_id");
    
    given ($type) {
    	when ('party') {
    		croak "Invalid combat log" unless $id == $c->stash->{party}->id;	
    	}
    	when ('garrison') {
    		my $garrison = $c->model('DBIC::Garrison')->find(
    			{
    				garrison_id => $id,
    				party_id => $c->stash->{party}->id,
    			},
    		);
    		croak "Invalid combat log" unless $garrison;
    	}
    }

    my @messages = $c->model('DBIC::Combat_Log_Messages')->search(
    	{
    		combat_log_id => $combat_log->id,
    		opponent_number => $opp_num,
    	},
    	{
    		order_by => 'round',
    	},
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/combat_messages.html',
                params   => {
                    messages  => \@messages,
                    party => $c->stash->{party},
                },
            }
        ]
    );	
}

sub options : Local {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template     => 'party/details/options.html',
                params       => { 
                	flee_threshold => $c->stash->{party}->flee_threshold,
                	send_daily_report => $c->stash->{party}->player->send_daily_report,
                	send_email_announcements => $c->stash->{party}->player->send_email_announcements,
                	display_tip_of_the_day => $c->stash->{party}->player->display_tip_of_the_day,
                	display_announcements => $c->stash->{party}->player->display_announcements,
                	send_email => $c->stash->{party}->player->send_email,
                },
                fill_in_form => 1,
            }
        ]
    );
}

sub update_options : Local {
    my ( $self, $c ) = @_;

    if ( $c->req->param('save') ) {
        $c->stash->{party}->flee_threshold( $c->req->param('flee_threshold') );
        $c->stash->{party}->update;
        $c->flash->{messages} = 'Changes Saved';
    }

    $c->res->redirect( $c->config->{url_root} . '/party/details?tab=options' );
}

sub update_email_options : Local {
    my ( $self, $c ) = @_;

    if ( $c->req->param('save') ) {
    	my $player = $c->stash->{party}->player;
        $player->send_daily_report($c->req->param('send_daily_report') ? 1 : 0);
        $player->send_email_announcements($c->req->param('send_email_announcements') ? 1 : 0);
        $player->display_announcements($c->req->param('display_announcements') ? 1 : 0);
        $player->display_tip_of_the_day($c->req->param('display_tip_of_the_day') ? 1 : 0);
        $player->send_email($c->req->param('send_email') ? 1 : 0);
        $player->update;
        $c->flash->{messages} = 'Changes Saved';
    }

    $c->res->redirect( $c->config->{url_root} . '/party/details?tab=options' );
}

sub garrisons : Local {
	my ($self, $c) = @_;
	
	my @garrisons = $c->stash->{party}->garrisons;
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/garrisons.html',
                params   => {
                    garrisons => \@garrisons,
                },
            }
        ]
    );	
}

sub mayors : Local {
	my ($self, $c) = @_;
	
	my @mayors = $c->stash->{party}->search_related(
		'characters',
		{
			mayor_of => {'!=', undef},
		},
		{
			prefetch => 'mayor_of_town',
		}
	);	
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/mayors.html',
                params   => {
                    mayors => \@mayors,
                },
            }
        ]
    );	
}

sub buildings : Local {
	my ($self, $c) = @_;

	my @buildings = $c->stash->{party}->get_owned_buildings();
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/buildings.html',
                params   => {
                    buildings => \@buildings,
                },
            }
        ]
    );	
}

sub kingdom : Local {
	my ($self, $c) = @_;
	
	my $kingdom = $c->stash->{party}->kingdom;
	
	if ($kingdom->king->party_id == $c->stash->{party}->id) {
        $c->forward(
            'RPG::V::TT',
            [
                {
                    template => 'kingdom/summary.html',
                    params => {
                        kingdom => $kingdom,  
                    },
                }
            ]
        );
        return;
	}
	
	my @kingdoms = $c->model('DBIC::Kingdom')->search(
	   {
	       active => 1,
	       kingdom_id => {'!=', $c->stash->{party}->kingdom_id},
	   },
	   {
	       order_by => 'name',
	   }
    );
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/kingdom.html',
                params   => {
                    kingdom => $kingdom,
                    kingdoms => \@kingdoms,
                    allegiance_change_frequency => $c->config->{party_allegiance_change_frequency},
                    party => $c->stash->{party},
                },
            }
        ]
    );		
}

sub change_allegiance : Local {
	my ($self, $c) = @_;
	
	my $day = $c->stash->{party}->last_allegiance_change_day;
	if ($day && abs $day->difference_to_today <= $c->config->{party_allegiance_change_frequency}) {
	   $c->flash->{error} = "You changed your allegiance too recently";
	   $c->res->redirect( $c->config->{url_root} . '/party/details?tab=kingdom' );
	   return;
	}
	
	my $kingdom;
	if ($c->req->param('kingdom_id')) {
	   $kingdom = $c->model('DBIC::Kingdom')->find(
	       {
	           kingdom_id => $c->req->param('kingdom_id'),
	       }  
	   );
	   croak "Kingdom doesn't exist\n" unless $kingdom;
	}
	
	if ($kingdom->king->party_id == $c->stash->{party}->id) {
	   croak "Can't change your allegieance when you have the king!\n";	       
	}
	
	$c->stash->{party}->kingdom_id($c->req->param('kingdom_id'));
	$c->stash->{party}->last_allegiance_change($c->stash->{today}->id);
	$c->stash->{party}->update;
	
	$c->flash->{messages} = "Allegiance changed";
	
	$c->res->redirect( $c->config->{url_root} . '/party/details?tab=kingdom' );
}

1;
