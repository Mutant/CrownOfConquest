package RPG::C::Help;

use strict;
use warnings;
use base 'Catalyst::Controller';

use List::Util qw(shuffle);

sub default : Path {
	my ($self, $c) = @_;
	
	my $action = $c->req->path;
	$action =~ s|^/||;
	
	if ($action eq 'help') {
		# If we have a party loaded in the stash, then the party has finished being created, so redirect to main help page.
		#  Otherwise redirect to party creation help page
		if ($c->stash->{party}) {
			$action = 'help/main';
		}
		else {
			$action = 'help/create_party';
		}
	}
	
	my $template =  $action . '.html';
	
	$c->forward('RPG::V::TT',
        [{
            template => $template,
        }]
    );	
}

sub about : Local {
	my ($self, $c) = @_;	
	
	$c->forward('RPG::V::TT',
        [{
            template => 'help/about.html',
        }]
    );	
}

sub tips : Local {
	my ($self, $c) = @_;	
	
	my @tips = shuffle $c->model('DBIC::Tip')->search();
	
	$c->forward('RPG::V::TT',
        [
        	{
            	template => 'help/tips.html',
            	params => {
            		tips => \@tips,
            	},
        	},
        ]
    );		
}

1;