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
    	# TODO: wotamess
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
            	my $enchanted = $item_found->{item}->enchantments_count > 0 ? 1 : 0;
                push @messages, $item_found->{finder}->character_name . " found a " . $item_found->{item}->display_name 
                	. ($enchanted ? '(*)' : '') . "\n";
            }

            given ( $opponent->group_type ) {
            	when ('creature_group') { 
                	push @messages, "You've killed the creatures\n";
            	}
            	when ('party') {
                	push @messages, "You've wiped out the party\n";
            	}
            	when ('garrison') {
            		push @messages, "You've wiped out the garrison\n";
            	}
            }
        }
        else {
        	given ( $group->group_type ) {
        		when ('party') {
            		push @messages, "Your party has been wiped out!\n";
        		}
        		when ('garrison') {
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