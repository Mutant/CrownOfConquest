package RPG::C::Admin::Reward;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature 'switch';

sub default : Path {
	my ($self, $c) = @_;
	
	my %params;
	
	if ($c->req->param('player_name')) {
	   $c->session->{player_name} = $c->req->param('player_name');
	   $c->session->{amount} = $c->req->param('amount');
	   $c->session->{type} = $c->req->param('type');
	   
	   %params = (
	       player_name => $c->req->param('player_name'),
	       amount => $c->req->param('amount'),
	       type => $c->req->param('type'),
	   ); 
	}
	
	if ($c->req->param('confirmed')) {
	   my $player = $c->model('DBIC::Player')->find(
	       {
	           player_name => $c->session->{player_name},
	       }
	   );
	   
	   if (! $player) {	   
	       $params{error} = "No such player: " . $c->session->{player_name};
	   }
	   else {
	       my ($party) = $player->search_related('parties', {defunct => undef});
	       
	       given ($c->session->{type}) {
	           when ('Turns') {
	               # Use hidden accessor to allow exceeding max turns
	               $party->_turns($party->_turns + $c->session->{amount});
	           }
	           when ('Gold') {
	               $party->increase_gold($c->session->{amount});
	           }
	       }
	       $party->update;
	       
	       $party->add_to_messages(
	           {
	               message => "You were awarded " . $c->session->{amount} . ' ' . $c->session->{type} . ' by the Administrators.',
	               day_id => $c->model('DBIC::Day')->find_today->id,
	               alert_party => 1,
	           }
	       );
	       
	       $c->log->debug("Rewarded party ". $party->id . " with " . $c->session->{amount} . ' ' . $c->session->{type});
	       
	       $params{message} = "Reward given to party: " . $party->name;
	   }
	   
	   undef $c->session->{player_name};
	   undef $c->session->{amount};
	   undef $c->session->{type};
	}
	
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/reward/main.html',
                params   => \%params,
            }
        ]
    );		
}

1;