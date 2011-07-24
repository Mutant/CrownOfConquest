package RPG::C::Panel;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;
use List::MoreUtils qw(uniq);
use DateTime;

my %PANEL_PATHS = (
	party => '/party/list',
	party_status => '/party/status',
	zoom => '/party/zoom',
	creatures => '/combat/display_opponents',
	mini_map => '/map/kingdom',
);

sub refresh : Private {
	my ($self, $c, @panels_to_refresh) = @_;
	
	$c->forward('check_for_mini_map_refresh');
			
	@panels_to_refresh = uniq ( @panels_to_refresh, @{ $c->stash->{refresh_panels} }, @{ $c->flash->{refresh_panels} } )
		if ($c->stash->{refresh_panels} && ref $c->stash->{refresh_panels} eq 'ARRAY') ||
		   ($c->flash->{refresh_panels} && ref $c->flash->{refresh_panels} eq 'ARRAY');		
	
	$c->log->info("Refreshing these panels: " . join ',',@panels_to_refresh);
	
	delete $c->flash->{refresh_panels};
		
	my %response;
	
	if ($c->stash->{error}) {
		$response{error} = $c->stash->{error};
	}
	
	if ($c->stash->{dialog_to_display}) {
		$response{displayDialog} = $c->stash->{dialog_to_display};
	}
	
	foreach my $panel (@panels_to_refresh) {
		unless (ref $panel eq 'ARRAY') {
			if ($panel eq 'messages') {
				$c->forward('day_logs_check');
                $c->forward('messages');
			}
			
			my $panel_path = $c->forward('find_panel_path', [$panel]);
			$c->log->debug("Path for $panel: " . $panel_path);
			$response{refresh_panels}{$panel} = $c->forward($panel_path);
		}
		elsif ($panel->[0] eq 'screen') {
            $response{screen_to_load} = $panel->[1];
		}
		elsif ($panel->[0] eq 'redirect') {
		    $response{redirect} = $panel->[1];
		}
		else {
			$response{refresh_panels}{$panel->[0]} = $panel->[1];
		}
	}

	if ($c->stash->{panel_messages}) {
	    if (! ref $c->stash->{panel_messages}) {
	        $c->stash->{panel_messages} = [$c->stash->{panel_messages}];
	    } 
	    
		confess "Panel messages must be an arrayref" unless ref $c->stash->{panel_messages} eq 'ARRAY';
		$response{panel_messages} = $c->stash->{panel_messages};
	}
	
	$response{panel_callbacks} = $c->stash->{panel_callbacks};
		
	$response{message_panel_size} = $c->stash->{message_panel_size} // 'small';
		
    my $resp = to_json \%response;
    $resp =~ s|script>|scri"+"pt>|g; # Nasty hack

    $c->res->body( $resp );
}

sub find_panel_path : Private {
	my ($self, $c, $panel) = @_;
	
	$c->log->debug("Finding panel path for: $panel");
	
	my $path = $PANEL_PATHS{$panel};
	
	return $path if $path;
	
    my $party = $c->stash->{party};
    
    if ($panel eq 'messages') {   	
        if ($c->stash->{messages_path}) {
            return $c->stash->{messages_path};
        }        
    	elsif ($party->in_combat_with) {
    	    $c->stash->{message_panel_size} = 'large';
    		return '/combat/switch';
    	}	
    	elsif ($party->dungeon_grid_id) {
    	    return '/dungeon/sector_menu';
    	}
    	elsif ($c->stash->{party_location}->town) {
    	    $c->stash->{message_panel_size} = 'large';
    		return '/town/main';
    	}
    	elsif ($party->in_party_battle) {
    		return '/party/combat/main';
    	}    	
    	else {
    		return '/party/sector_menu';
    	}
    }
    
    if ($panel eq 'map') {
        if ($party->dungeon_grid_id) {
            return '/dungeon/view';
        }
        else {
            return '/map/view';
        }
    }
    
    confess "Unknown panel: $panel";
}

sub day_logs_check : Private {
	my ($self, $c) = @_;
	
	# Don't check if the party is currently in combat
	return if $c->stash->{party}->in_combat;
	
	$c->session->{last_day_log_check} //= DateTime->now();
	
	if (DateTime->compare($c->session->{last_day_log_check}, DateTime->now->subtract( minutes => 15 ) ) == 1 ) {
	   return;
	}
	
    # Check if new day message should be displayed
    my ($day_log) = $c->model('DBIC::DayLog')->search(
    	{
    		'displayed' => 0,
    		'party_id' => $c->stash->{party}->id,
    	},
    	{
    		order_by => 'day.date_started desc',
    		prefetch => 'day',
    		rows => 1,
    	},
    );
    
    if ($day_log) {
    	$c->model('DBIC::DayLog')->search(
	    	{
	    		'displayed' => 0,
	    		'party_id' => $c->stash->{party}->id,
	    	}
		)->update( { displayed => 1 } );
    	
    	$c->stash->{day_logs} = $c->forward('RPG::V::TT',
	        [{
	            template => 'party/day_logs.html',
				params => {
					day_log => $day_log,
				},
				return_output => 1,
	        }]		       
   		);   			
    }
}

sub messages : Private {
	my ($self, $c) = @_;
	
    # Get recent combat count if party has been offline
    if ( $c->stash->{party}->last_action <= DateTime->now()->subtract( minutes => $c->config->{online_threshold} ) ) {
        my $offline_combat_count = $c->model('DBIC::Combat_Log')->get_offline_log_count( $c->stash->{party} );
        if ( $offline_combat_count > 0 ) {
            push @{ $c->stash->{messages} }, $c->forward(
                'RPG::V::TT',
                [
                    {
                        template      => 'party/offline_combat_message.html',
                        params        => { offline_combat_count => $offline_combat_count },
                        return_output => 1,
                    }
                ]
            );
        }
        
        my @garrison_counts = $c->model('DBIC::Combat_Log')->get_offline_garrison_log_count( $c->stash->{party} );
        if (@garrison_counts) {
            push @{ $c->stash->{messages} }, $c->forward(
                'RPG::V::TT',
                [
                    {
                        template      => 'party/offline_garrison_combat_message.html',
                        params        => { garrison_counts => \@garrison_counts },
                        return_output => 1,
                    }
                ]
            );
        }
    }
}

# Create a dialog when the panels are reloaded. Submits form values to a given URL
# Uses a panel callback to do this
# Just needs to be forward to by the controller before calling 'refresh_panels'
sub create_submit_dialog : Private {
	my ($self, $c, $params) = @_;
	
	my %callback = (
		name => 'dialog',
		data => {
			content => $params->{content},
			submit_url => $params->{submit_url},
			parse_content => $params->{parse_content} // 1,
			dialog_title => $params->{dialog_title},
		}
	);
	
	$c->log->debug("Displaying dialog: " . Dumper \%callback);
	
	push @{$c->stash->{panel_callbacks}}, \%callback; 
}

# Refresh specified panels, loading a template with params into 
#  one particular panel
sub refresh_with_template : Private {
    my ($self, $c, $params) = @_;
    
    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => $params->{template},
                params   => $params->{params},
                fill_in_form => $params->{fill_in_form},
                return_output => 1,
            }
        ]
    );
    
    $params->{panel_to_load} //= 'messages';
    
	push @{ $c->stash->{refresh_panels} }, [ $params->{panel_to_load}, $panel ];

    $params->{panels_to_refresh} //= [];

	$c->forward('/panel/refresh', $params->{panels_to_refresh});
}

# Refresh the mini_map every n minutes
sub check_for_mini_map_refresh : Private {
    my ($self, $c) = @_;
    
    $c->session->{last_mini_map_refresh} //= DateTime->now();
        
    if (DateTime->compare(DateTime->now->subtract('minutes' => 5), $c->session->{last_mini_map_refresh}) == 1) {
        push @{$c->stash->{refresh_panels}}, 'mini_map';
        $c->session->{last_mini_map_refresh} = DateTime->now();
    }
}

1;
