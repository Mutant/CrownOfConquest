package RPG::C::Panel;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;
use List::MoreUtils qw(uniq);

my %PANEL_PATHS = (
	party => '/party/list',
	party_status => '/party/status',
	zoom => '/party/zoom',
);

sub refresh : Private {
	my ($self, $c, @panels_to_refresh) = @_;
		
	@panels_to_refresh = uniq ( @panels_to_refresh, @{ $c->stash->{refresh_panels} } )
		if $c->stash->{refresh_panels} && ref $c->stash->{refresh_panels} eq 'ARRAY';		
	
	$c->log->info("Refreshing these panels: " . join ',',@panels_to_refresh);
	
	my %response;
	
	if ($c->stash->{error}) {
		$response{error} = $c->stash->{error};
	}

	foreach my $panel (@panels_to_refresh) {
		unless (ref $panel eq 'ARRAY') {
			if ($panel eq 'messages') {
				$c->forward('day_logs_check');
			}
			
			my $panel_path = $c->forward('find_panel_path', [$panel]);
			$c->log->debug("Path for $panel: " . $panel_path);
			$response{refresh_panels}{$panel} = $c->forward($panel_path);
		}
		else {
			$response{refresh_panels}{$panel->[0]} = $panel->[1];
		}
	}

	if ($c->stash->{panel_messages}) {
		$response{panel_messages} = $c->stash->{panel_messages};
	}
	
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
    	elsif ($c->stash->{party_location}->town) {
    		return '/town/main';
    	}
    	elsif ($party->in_combat_with) {
    		return '/combat/main';
    	}
    	elsif ($party->in_party_battle) {
    		return '/party/combat/main';
    	}    	
    	elsif ($party->dungeon_grid_id) {
    	    return '/dungeon/sector_menu';
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
	
    # Check if new day message should be displayed
    my @day_logs = $c->model('DBIC::DayLog')->search(
    	{
    		'displayed' => 0,
    		'party_id' => $c->stash->{party}->id,
    	},
    	{
    		order_by => 'day.date_started desc',
    		prefetch => 'day',
    		rows => 7, # TODO: config me
    	},
    );
    
    if (@day_logs) {
    	foreach my $day_log (@day_logs) {   		
    		$day_log->displayed(1);
    		$day_log->update;
    	}
    	
    	$c->stash->{day_logs} = $c->forward('RPG::V::TT',
	        [{
	            template => 'party/day_logs.html',
				params => {
					day_logs => \@day_logs,
				},
				return_output => 1,
	        }]		       
   		);
   			
    }
}

1;