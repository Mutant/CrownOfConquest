package RPG::Schema::Quest::Construct_Building;

use strict;
use warnings;

use base 'RPG::Schema::Quest';

use List::Util qw(shuffle);
use RPG::Map;

use feature 'switch';

sub set_quest_params {
    my $self = shift;
    
    # Find a sector for the building
    my $kingdom = $self->kingdom;
    my @border_sectors = shuffle $kingdom->border_sectors;
 
    my $sector_to_use;
    my $checked;
    
    # Find a sector near the border of the kingdom without any buildings or towns within range
    OUTER: foreach my $check_sector (@border_sectors) {        
        # Find the sector near the border sector to use
        my ($start_point, $end_point) = RPG::Map->surrounds($check_sector->{x}, $check_sector->{y}, $self->{_config}{search_range}, $self->{_config}{search_range});
        
        my @sectors = shuffle $self->result_source->schema->resultset('Land')->search(
            {
                'x' => { '>=', $start_point->{x}, '<=', $end_point->{x}, },
                'y' => { '>=', $start_point->{y}, '<=', $end_point->{y}, },
            },
        );
       
        foreach my $sector (@sectors) {        
            next if $checked->{$sector->x}{$sector->y};
            
            $checked->{$sector->x}{$sector->y} = 1;
                        
            # Check for existing buildings around the sector
            my @buildings = $self->result_source->schema->resultset('Building')->find_in_range(
                {
                    x => $sector->x,
                    y => $sector->y,
                },
                $self->{_config}{building_search_range},
            );
            
            # Try another sector if there are buildings in range
            # TODO: possibly could be ok, especially if they're not owned by this kingdom?
            #  Or perhaps there should be another quest to seize buildings near the borders
            #  not owned by the kingdom
            next if @buildings;
            
            my @towns = $self->result_source->schema->resultset('Town')->find_in_range(
                {
                    x => $sector->x,
                    y => $sector->y,
                },
                $self->{_config}{building_search_range},
                0, 1
            );
            
            # Also skip if there are towns within range, since they provide similar benefits
            next if @towns;
        
            $sector_to_use = $sector;
        
            last OUTER;
        }
    }
    
    unless ($sector_to_use) {        
        die RPG::Exception->new(
            message => "Can't create quest - no suitable border sectors to create buildings",
            type    => 'quest_creation_error',
        );
    }
    
    $self->define_quest_param( 'Building Location', $sector_to_use->id );
    
    # Set building type.
    # TODO: for now, hard-coded to 'Tower'. If there are other types in the future, this will
    #  need to be changed
    my $building_type = $self->result_source->schema->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
    
    $self->define_quest_param( 'Building Type', $building_type->id );
    $self->define_quest_param( 'Built', 0 );
    
    $self->days_to_complete(10);
    $self->min_level(RPG::Schema->config->{minimum_building_level});
    $self->gold_value(10000);
    $self->xp_value(1000);
    $self->update;
       
}

sub interested_in_actions {
    my $self = shift;

    return ('constructed_building', 'ceded_building');
}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;
    my $building = shift;
    
    my $land = $building->location;
    
    return 0 unless $building->building_type_id == $self->param_current_value('Building Type');

    given ($action) {
        when ('constructed_building') {
            if ($land->id eq $self->param_current_value('Building Location')) {
                my $quest_param = $self->param_record('Built');
                
                return 0 if $quest_param->current_value eq 1;
                
                $quest_param->current_value(1);
                $quest_param->update;

                return 1;
            }
        }
        when ('ceded_building') {
            if ($land->id eq $self->param_current_value('Building Location') && $building->owner_id == $party->kingdom_id && $building->owner_type eq 'kingdom') {
           
                $self->status('Awaiting Reward');
                $self->update; 
                
                return 1;
            }
        }
    }
    
    return 0;
}

sub sector_to_build_in {
    my $self = shift;
    
    return $self->result_source->schema->resultset('Land')->find( $self->param_start_value('Building Location') );
}

sub building_type_to_create {
    my $self = shift;
    
    return $self->result_source->schema->resultset('Building_Type')->find( $self->param_start_value('Building Type') );
}

1;