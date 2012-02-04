package RPG::NewDay::Action::Building_Upgrades;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;

use feature 'switch';

sub run {
    my $self = shift;

    my $c = $self->context;
    
    my @upgrades = $c->schema->resultset('Building_Upgrade')->search(
        {
            name => ['Market', 'Barracks'],
        },
        {
            prefetch => 'building',
        }
    );
    
    foreach my $upgrade (@upgrades) {
        given ($upgrade->name) {
            when ('Market') {
                $self->process_market($upgrade);
            }
            when ('Barrcks') {
                $self->process_barracks($upgrade);
            }
        }
    }
}

sub process_market {
    my $self = shift;
    my $upgrade = shift;
    
    my $c = $self->context;
    
    my $owner = $upgrade->building->owner;
    
    my $gold = Games::Dice::Advanced->roll('1d10') * $upgrade->level;
    
    $owner->gold($owner->gold + $gold);
    $owner->update;
    
    my $location = $upgrade->building->location;
    my $message = "The Market in the building at " . $location->x . ", " . $location->y . " generated $gold gold";
    
    if ($upgrade->building->owner_type eq 'town') {
        $owner->add_to_history(
            {
                message => $message,
                day_id => $c->current_day->id,
            }
        );        
    
    	$owner->add_to_history(
    		{
    			type => 'income',
    			value => $gold,
    			message => 'Market Revenue',
    			day_id => $c->current_day->id,
    		}
    	);
    }
    else {
        $owner->add_to_messages(
            {
                message => $message,
                day_id => $c->current_day->id,
            }
        );          
    }
}

1;