package RPG::C::Party::Details;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use feature "switch";

sub default : Path {
    my ( $self, $c ) = @_;
    
    my @old_parties = $c->model('DBIC::Party')->search(
        {
            player_id => $c->session->{player}->id,
            defunct => {'!=', undef},
        },
        {
            order_by => 'created',
        }
    );

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
                    old_parties => \@old_parties,
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
    
    my $party;
    
    if ($c->req->param('party_id')) {
        $party = $c->model('DBIC::Party')->find(
            {
                party_id => $c->req->param('party_id'),
            }
        );        
        croak "Can't access party from another player" unless $party->player_id == $c->session->{player}->id;
    }
    else {
        $party = $c->stash->{party};
    }

    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_party( $party, 20 );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/combat_log.html',
                params   => {
                    logs  => \@logs,
                    party => $party,
                    old_party => $party->id != $c->stash->{party}->id ? 1 : 0,
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
    	    if ($id != $c->stash->{party}->id) {
                my $old_party = $c->model('DBIC::Party')->find(
                    {
                        party_id => $id,
                        player_id => $c->session->{player}->id,
                    }
                );
                
                croak "Invalid combat log" unless $old_party;
    	    } 	
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
	
	my @old_garrisons = $c->model('DBIC::Garrison')->search(
	   {
	       party_id => $c->stash->{party}->id,
	       land_id => undef,
	   }
    );
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/garrisons.html',
                params   => {
                    garrisons => \@garrisons,
                    old_garrisons => \@old_garrisons,
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
	
	my @old_mayors = $c->model('DBIC::Party_Mayor_History')->search(
	   {
	       party_id => $c->stash->{party}->id,
	       lost_mayoralty_day => {'!=', undef},
	   }
    );
	   
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/mayors.html',
                params   => {
                    mayors => \@mayors,
                    old_mayors => \@old_mayors,
                },
            }
        ]
    );	
}

sub old_mayor_combat_log : Local {
    my ($self, $c) = @_;
    
    my $history = $c->model('DBIC::Party_Mayor_History')->find(
        {
            creature_group_id => $c->req->param('creature_group_id'),
            party_id => $c->stash->{party}->id,
        }
    );
    
    croak "History not found" unless $history;
    
    my $cg = $c->model('DBIC::CreatureGroup')->find(
        {
            creature_group_id => $c->req->param('creature_group_id'),
        }
    );
    
    croak "CG not found" unless $cg;
    
    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_creature_group($cg, 20);
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/combat_log.html',
                params   => {
                    logs  => \@logs,
                    party => $cg,
                    old_party => 1,
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
	
	if ($kingdom && $kingdom->king->party_id == $c->stash->{party}->id) {
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
	       'me.kingdom_id' => {'!=', $c->stash->{party}->kingdom_id},
	   },
	   {
	       order_by => 'name',
	   }
    );
    
    @kingdoms = grep { 
        my $party_kingdom = $_->find_related('party_kingdoms',
            {
                'party_id' => $c->stash->{party}->id,
            }
        );
        $party_kingdom && $party_kingdom->banished_for > 0 ? 0 : 1;
    } @kingdoms;
    
    my @banned = $c->model('DBIC::Party_Kingdom')->search(
        {
            party_id => $c->stash->{party}->id,
            banished_for => {'>=', 0},
        },
        {
            prefetch => 'kingdom',
        }
    );
    
	my $mayor_count = $c->stash->{party}->search_related(
		'characters',
		{
			mayor_of => {'!=', undef},
		},
	)->count;	    
	
	my $can_declare_kingdom = $c->stash->{party}->level >= $c->config->{minimum_kingdom_level} 
	   && $mayor_count >= $c->config->{town_count_for_kingdom_declaration};
	
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
                    mayor_count => $mayor_count,
                    town_count_for_kingdom_declaration => $c->config->{town_count_for_kingdom_declaration},
                    minimum_kingdom_level => $c->config->{minimum_kingdom_level},
                    can_declare_kingdom => $can_declare_kingdom,
                    banned => \@banned,
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

    	if ($kingdom->king->party_id == $c->stash->{party}->id) {
    	   croak "Can't change your allegiance when you have the king!\n";	       
    	}
    	
    	my $king = $kingdom->king;
    	if (! $king->is_npc && $c->stash->{party}->is_suspected_of_coop_with($king->party)) {
            $c->flash->{error} = "You can't change your allegiance to that kingdom, as you have IP addresses in common with the king's party";
            $c->res->redirect( $c->config->{url_root} . '/party/details?tab=kingdom' );
            return;
    	}
	}

	$c->stash->{party}->change_allegiance($kingdom);
	$c->stash->{party}->update;
	
	$c->flash->{messages} = "Allegiance changed";
	
	$c->res->redirect( $c->config->{url_root} . '/party/details?tab=kingdom' );
}

sub trades : Local {
    my ($self, $c) = @_;
    
    my @trades = $c->model('DBIC::Trade')->search(
        {
            status => ['Offered', 'Accepted'],
            party_id => $c->stash->{party}->id,
        }
    );  
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/trades.html',
                params   => {
                    trades => \@trades,    
                }    
            }
        ],
    );
}

1;
