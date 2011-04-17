package RPG::Schema::Quest::Take_Over_Town;

use strict;
use warnings;

use base 'RPG::Schema::Quest';

use List::Util qw(shuffle);
use RPG::Map;

sub set_quest_params {
    my $self = shift;
    
    my $kingdom = $self->kingdom;
    
    my $town;
    
    # First look for towns within the kingdom that have mayors that aren't loyal
    my @towns = $self->result_source->schema->resultset('Town')->search(
        {
            'location.kingdom_id' => $kingdom->id,
            'party.kingdom_id' => [{'!=', $kingdom->id}, undef],
        },
        {
            join => [
                'location',
                {'mayor' => 'party'},
            ],
        }
    );
    
    # If there aren't any of the above, find towns near the borders
    if (! @towns) {
        my @border_sectors = shuffle $kingdom->border_sectors;
        
        foreach my $check_sector (@border_sectors) {
            my ($start_point, $end_point) = RPG::Map->surrounds(
                $check_sector->{x}, 
                $check_sector->{y}, 
                $self->{_config}{town_search_range}, 
                $self->{_config}{town_search_range}
            );
            
            my @towns = shuffle $self->result_source->schema->resultset('Town')->search(
                {
                    'location.x' => { '>=', $start_point->{x}, '<=', $end_point->{x}, },
                    'location.y' => { '>=', $start_point->{y}, '<=', $end_point->{y}, },
                    'location.kingdom_id' => [{ '!=', $kingdom->id }, undef],
                },
                {
                    join => 'location',
                }
            );
            
            next unless @towns;
            
            $town = (shuffle @towns)[0];
        }    
    }
    else {
        $town = (shuffle @towns)[0];
    }
    
    unless ($town) {
        $self->delete;
        die RPG::Exception->new(
            message => "Can't create quest - no towns to take over",
            type    => 'quest_creation_error',
        );
    }
    
    $self->define_quest_param( 'Town To Take Over', $town->id );
    
    $self->days_to_complete(10);
    $self->min_level(RPG::Schema->config->{minimum_raid_level});
    $self->gold_value(10000);
    $self->xp_value(1000);
    $self->update;
}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;
    my $town = shift;

    return 0 unless $town->id == $self->param_current_value('Town To Take Over');
    
    return 0 unless $action eq 'taken_over_town' || $action eq 'changed_town_allegiance';

    if ($town->location->kingdom_id == $self->kingdom_id) {
        # Town is loyal to kingdom, quest is complete
        $self->status("Awaiting Reward");
        $self->update;
    }
        
    return 1;
}

sub town {
    my $self = shift;
       
    return $self->result_source->schema->resultset('Town')->find( $self->param_start_value('Town To Take Over') );
}

1;
