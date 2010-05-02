use strict;
use warnings;

package RPG::Combat::MessageDisplayer;

use RPG::Template;

use feature 'switch';
use Carp;

sub display {
	my $self = shift;
	my %params = @_;
	
	my $result = $params{result} || confess "Result not defined";
	my $group = $params{group} || confess "Group not defined";
	my $opponent = $params{opponent} || confess "Opponent not defined";
	my $config = $params{config} || confess "Config not defined";
	
	my @messages;
	
    push @messages,
        RPG::Template->process(
        	$config,
        	'combat/message.html',
        	{
				combat_messages => $result->{messages},
                combat_complete => $result->{combat_complete},
                group           => $group,            
            }
        );

    if ( $result->{combat_complete} ) {
		if ( $result->{creatures_fled} ) {	
	        push @messages, "The creatures have fled!";
	
			my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );
	
	        push @messages, @xp_messages;
	
	    }
	    elsif ( $result->{offline_party_fled} ) {	
	        push @messages, "The party has fled!";
	
			my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );
				
	        push @messages, @xp_messages;
	    }
    	elsif ( ! $group->is($result->{losers}) ) {
            my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );

            push @messages, @xp_messages;

            push @messages, "You find $result->{gold} gold\n";

            foreach my $item_found ( @{ $result->{found_items} } ) {
                push @messages, $item_found->{finder}->character_name . " found a " . $item_found->{item}->display_name . "\n";
            }

            given ( $opponent->group_type ) {
            	when ('creature_group') { 
                	push @messages, "You've killed the creatures";
            	}
            	when ('party') {
                	push @messages, "You've wiped out the party";
            	}
            }
        }
        else {
        	given ( $group->group_type ) {
        		when ('party') {
            		push @messages, "Your party has been wiped out!";
        		}
        		when ('garrison') {
        			push @messages, "The garrison has been wiped out!";
        		}
        	}
        }
    }
   
    return @messages;

}

sub _xp_gain {
	my $self = shift;
	my $config = shift;
	my $group = shift;
	my $awarded_xp = shift;
	
	my @details = $group->xp_gain($awarded_xp);
    my @messages;

    foreach my $details (@details) {
        push @messages,
            RPG::Template->process(
            	$config,
            	'party/xp_gain.html',
            	$details,
        	);
    }

    return @messages;
}

1;