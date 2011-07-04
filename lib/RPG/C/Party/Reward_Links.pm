package RPG::C::Party::Reward_Links;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Digest::SHA1 qw(sha1_hex);
use List::Util qw(shuffle);

sub default : Path {
    my ($self, $c) = @_;
    
    $c->stash->{message_panel_size} = 'large';
    
    my %params;
    if (! $c->session->{player}->admin_user) {
        $params{activated} = 1;   
    }
    
    my @reward_links = $c->model('DBIC::Reward_Links')->search(
        {
            %params,
        },
        {
            order_by => ['turn_rewards desc', 'rand()'],
        }
    );
   
    # Create keys & links
    my @player_reward_links;
    foreach my $reward_link (@reward_links) {
        my $link = $c->model('DBIC::Player_Reward_Links')->find_or_create(
            {
                player_id => $c->session->{player}->id,
                link_id => $reward_link->id,
            }
        );
        
        
        $link->vote_key(sha1_hex(rand));
        $link->update;
        
        if (! $reward_link->template_url) {
            my $url = $reward_link->url . '?' . $reward_link->extra_params . '&' . $reward_link->user_field . '=' . $c->session->{player}->id;
            if ($reward_link->key_field) {
                $url .= '&' . $reward_link->key_field . '=' . $link->vote_key;
            }
            
            $link->{url} = $url;
        }
        else {
            my $url_tmpl = $reward_link->url;
            
            $link->{url} = $c->forward( 'RPG::V::TT', [
                {
                    template => \$url_tmpl,
                    params => {
                        key => $link->vote_key,
                        player_id => $c->session->{player}->id,
                    },
                    return_output => 1,
                }
            ]);
        }            
        
        push @player_reward_links, $link;
    }
   
	my $panel = $c->forward( 'RPG::V::TT', [ 
		{ 
			template => 'party/reward_links.html',
			params => {
				player_reward_links => \@player_reward_links,
			},
			return_output => 1,
		} 
	] );
	
	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');	
}

1;