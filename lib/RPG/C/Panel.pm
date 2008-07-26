package RPG::C::Panel;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

my %PANEL_PATHS = (
	map => '/map/view',
	party => '/party/list',
	party_status => '/party/status',
);

sub refresh : Private {
	my ($self, $c, @panels_to_refresh) = @_;
	
	@panels_to_refresh = ( @panels_to_refresh, @{ $c->stash->{refresh_panels} } )
		if $c->stash->{refresh_panels} && ref $c->stash->{refresh_panels} eq 'ARRAY';
	
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
			$response{refresh_panels}{$panel} = $c->forward($panel_path);
		}
		else {
			$response{refresh_panels}{$panel->[0]} = $panel->[1];
		}
	}

	
	$c->res->body(to_json \%response);
}

sub find_panel_path : Private {
	my ($self, $c, $panel) = @_;
	
	return $PANEL_PATHS{$panel} unless $panel eq 'messages';
	
    my $party = $c->stash->{party};    
		
	#$party->discard_changes; # TODO: needed?
	
	if ($c->stash->{party_location}->town) {
		return '/town/main';
	}
	elsif ($party->in_combat_with) {
		return '/combat/main';
	}
	else {
		return '/party/sector_menu';
	}	
}

sub day_logs_check : Private {
	my ($self, $c) = @_;
	
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