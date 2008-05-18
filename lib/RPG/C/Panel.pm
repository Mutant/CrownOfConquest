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
	
	if ($party->location->town) {
		return '/town/main';
	}
	elsif ($party->in_combat_with) {
		return '/combat/main';
	}
	else {
		return '/party/sector_menu';
	}	
}

1;