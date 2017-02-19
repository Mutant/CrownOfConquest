use strict;
use warnings;

package RPG::Combat::MessageDisplayer;

use RPG::Template;

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
                weapons         => $params{weapons},
            }
        );    

    if ( $result->{combat_complete} ) {
    	# TODO: wotamess
    	#  The problem is, we're essentially using the code below to decide on aspects of the result of the combat
    	#  (including on whether to reward xp if one side fled). The way the result is handled when fleeing occurs
    	#  probably needs to be changed. If it simply indicated which side fled, then the other side could get awarded
    	#  xp, and appropriate messages generated. This could also occur in Battle.pm instead of here. The current
    	#  version also doesn't account for the fact that a creature group can gain xp (i.e. mayors). This is why we
    	#  don't give creature groups a decent message for end of combat.
    	
    	if ( $group->group_type eq 'creature_group' ) {
    	   push @messages, "The battle is over";
    	   return @messages;
    	}
		
		# These many if statements handle the message + xp gain for garrisons/parties who won
		if ( $result->{creatures_fled} ) {
	        push @messages, "The creatures have fled!\n";
	
			my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );
	
	        push @messages, @xp_messages;
	
	    }
	    elsif ( $result->{offline_party_fled} || $group->group_type eq 'garrison' && $result->{party_fled} ) {	
	        push @messages, "The party has fled!\n";
	
			my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );
				
	        push @messages, @xp_messages;
	    }
	    elsif ( $result->{garrison_fled} && $group->group_type eq 'party' ) {
			push @messages, "The garrison has fled!\n";	    
			
			my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );
				
	        push @messages, @xp_messages;
	    }
	    elsif ( $result->{party_fled} || $result->{garrison_fled} ) {
	    	push @messages, "You fled the battle!\n";
	    }
	    elsif ( $result->{stalemate} ) {
	    	push @messages, "The battle was a stalemate\n";
	    }
    	elsif ( ! $group->is($result->{losers}) ) {
            my @xp_messages = $self->_xp_gain($config, $group, $result->{awarded_xp} );

            push @messages, @xp_messages;

            push @messages, "You find $result->{gold} gold\n";

            foreach my $item_found ( @{ $result->{found_items} } ) {
                push @messages, $item_found->{finder}->character_name . " found a " . $item_found->{item}->display_name(1) . "\n";
            }

            for ( $opponent->group_type ) {
            	if ($_ eq 'creature_group') { 
                	push @messages, "You've killed the creatures\n";
            	}
            	elsif ($_ eq 'party') {
                	push @messages, "You've wiped out the party\n";
            	}
            	elsif ($_ eq 'garrison') {
            		push @messages, "You've wiped out the garrison\n";
            	}
            }
        }
        else {
        	for ( $group->group_type ) {
        		if ($_ eq 'party') {
            		push @messages, "Your party has been wiped out!\n";
        		}
        		elsif ($_ eq 'garrison') {
        			push @messages, "Your garrison has been wiped out!\n";
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
	
	# TODO: xp_gain should probably be called in Battle.pm
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