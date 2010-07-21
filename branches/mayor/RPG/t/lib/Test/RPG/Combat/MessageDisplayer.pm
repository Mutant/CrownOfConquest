use strict;
use warnings;

package Test::RPG::Combat::MessageDisplayer;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;

use RPG::Combat::MessageDisplayer;
use RPG::Combat::ActionResult;

sub test_display : Tests() {
	my $self = shift;
	
	# GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
    my $char = ($party->characters)[0];
    my $cret = ($cg->creatures)[0];
    
    my $result = {
    	messages => [
			RPG::Combat::ActionResult->new(
				defender => $cret,
				attacker => $char,
				damage => 3,
				defender_killed => 1,
			),
    	],
    	combat_complete => 1,
    	losers => $cg,
    	gold => 22,    	
    };
    
    my $config;
    $config->{home} = '/home/sam/RPG';
    
    # WHEN
    my $messages = join "\n", RPG::Combat::MessageDisplayer->display(
    	config => $config,
    	result => $result,
    	group => $party,
    	opponent => $cg,
    );
    
    # THEN
    like($messages, qr/You've killed the creatures/, "End of combat message returned");
	like($messages, qr/You find 22 gold/, "Message for gold found returned");
    
}

1;