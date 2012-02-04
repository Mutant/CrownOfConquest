package RPG::NewDay::Action::Building_Upgrades;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;
use RPG::Template;

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
    
    my $gold = Games::Dice::Advanced->roll('1d10') * $upgrade->level * 10;
    
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

sub process_barracks {
    my $self = shift;
    my $upgrade = shift;
    
    my $c = $self->context;
    
    my $building = $upgrade->building;
    
    my $group;
    my $message_entity;
    my $message_method;
    
    if ($building->owner_type eq 'town') {
        my $town = $building->owner;
        
        my $mayor = $town->mayor;
        
        return unless $mayor;
        
        $group = $mayor->creature_group;
        
        $message_entity = $town;
        $message_method = 'add_to_history';
    }
    else {
        $group = $c->schema->resultset('Garrison')->find(
            {
                land_id => $building->land_id,
            }
        );
        
        $message_entity = $group;
        $message_method = 'add_to_messages';
    }
    
    return if ! $group || $group->number_alive <= 0;
    
    my $xp_gain = Games::Dice::Advanced->roll('1d10') * $upgrade->level * 5;
    
    my $xp_each = int $xp_gain / $group->number_alive(characters_only => 1);
    
    my @details = $group->xp_gain($xp_each);
    
    my $message = RPG::Template->process(
        $c->config,
        'newday/building_upgrades/barracks.html',
        {
            awarded_xp => $xp_gain,
            xp_messages => \@details,
        }
    );

    $message_entity->$message_method(
        {
            message => $message,
            day_id => $c->current_day->id,
        }
    );
    
}

1;