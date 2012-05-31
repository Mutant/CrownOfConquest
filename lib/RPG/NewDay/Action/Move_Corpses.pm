package RPG::NewDay::Action::Move_Corpses;

use Moose;
use Games::Dice::Advanced;
use Try::Tiny;
use List::Util qw(shuffle);

extends 'RPG::NewDay::Base';

# Move corpses from wilderness into nearby town morgues.
sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my @corpses = $c->schema->resultset('Character')->search(
        {
            status => 'corpse',
            'party.defunct' => undef,
        },
        {
            prefetch => 'party',
        }
    );
    
    foreach my $corpse (@corpses) {        
        next unless Games::Dice::Advanced->roll('1d100') <= 10;
        
        my $location = $c->schema->resultset('Land')->find(
            {
                land_id => $corpse->status_context,
            }
        );
        
        my @towns = try {
            $c->schema->resultset('Town')->find_in_range(
                {
                    x => $location->x,
                    y => $location->y,
                },
                5,
                2,
                0,
                15,
            );
        }
        catch {
            if (ref $_ && $_->type eq 'find_in_range_error') {
                next;
            }
            die $_;
        };
        
        my $town = (shuffle @towns)[0];
        
        return unless $town;
        
        $corpse->status('morgue');
        $corpse->status_context($town->id);
        $corpse->update;
        
        $corpse->party->add_to_messages(
            {
				message =>  $corpse->character_name . " corpse was collected by the healer of " . $town->town_name . ", and interred in the town's morgue",
				alert_party => 1,
				day_id => $c->current_day->id,
            }
        );
    }
    
}

1;