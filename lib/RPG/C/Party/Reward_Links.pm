package RPG::C::Party::Reward_Links;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Digest::SHA1 qw(sha1_hex);

sub default : Path {
    my ($self, $c) = @_;
    
    my @reward_links = $c->model('DBIC::Reward_Links')->search(
        {
            activated => 1,
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
        
        push @player_reward_links, $link;
    }
   
	$c->forward( 'RPG::V::TT', [ 
		{ 
			template => 'party/reward_links.html',
			params => {
				player_reward_links => \@player_reward_links,
			} 
		} 
	] );
}

1;