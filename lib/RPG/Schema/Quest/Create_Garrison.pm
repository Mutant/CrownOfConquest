package RPG::Schema::Quest::Create_Garrison;

use strict;
use warnings;

use base 'RPG::Schema::Quest';

use List::Util qw(shuffle);
use RPG::Map;
use Games::Dice::Advanced;

sub set_quest_params {
    my $self = shift;
    
    my $kingdom = $self->kingdom;
    
    my $location;
    
    # First, check for any buildings owned by the Kingdom that don't have garrisons
    my @buildings = $self->result_source->schema->resultset('Building')->search(
        {
            owner_type => 'kingdom',
            owner_id => $kingdom->id,
        }
    );
    
    if (@buildings) {
        foreach my $building (@buildings) {        
            my $sector = $building->location;
            next if $sector->garrison && $sector->garrison->party->kingdom_id == $self->kingdom_id;
            $location = $sector;
            last;
        }   
    }
    
    if (! $location) {
        # Find a random sector near the border
        my @border_sectors = shuffle $kingdom->border_sectors;
        
        foreach my $sector (@border_sectors) {
            my $land = $self->result_source->schema->resultset('Land')->find( $sector->{land_id} );
            
            next if $land->garrison;
            
            $location = $land;
            last;   
        }
    }
    
    $self->define_quest_param( 'Location To Create', $location->id );
    $self->define_quest_param( 'Created', 0 );
    my $days_to_hold = Games::Dice::Advanced->roll( '1d4' ) + 8;
    $self->define_quest_param( 'Days To Hold', $days_to_hold );
    
    $self->days_to_complete(6 + $days_to_hold);
    $self->min_level(RPG::Schema->config->{minimum_garrison_level});
    
    my $value = (Games::Dice::Advanced->roll('1d100') * 10) + 500;
    $self->gold_value($value);
    $self->xp_value(750);
    $self->update;    
    
}

# Xp goes to the garrison created
#  (If we're not able to find it, just give it to the party instead)
sub xp_awarded_to {
    my $self = shift;
    
    my $garrison = $self->result_source->schema->resultset('Garrison')->find(
        {
            party_id => $self->party_id,
            land_id => $self->param_current_value( 'Location To Create' ),
        }
    );
    
    return $garrison // $self->party;    
}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;
    my $garrison = shift;
    
    return 0 unless grep { $_ eq $action } qw(garrison_created garrison_removed new_day); 
    
    # New day action doesn't populate garrison
    $garrison //= $self->sector_to_create_in->garrison;

    return 0 unless $garrison && $garrison->land_id == $self->param_current_value( 'Location To Create' );
    
    return 0 unless $garrison->party_id == $self->party_id;
    
    if ($action eq 'garrison_created') {
        
        my $quest_param = $self->param_record('Created');                
        $quest_param->current_value(1);
        $quest_param->update;
        
        return 1;        
    }
    elsif ($action eq 'garrison_removed') {
        # They removed the garrison... reset the params
        my $quest_param = $self->param_record('Created');                
        $quest_param->current_value(0);
        $quest_param->update;      
        
        $quest_param = $self->param_record('Days To Hold');
        $quest_param->current_value($quest_param->start_value);
        $quest_param->update;
        
        return 1;             
    }
    elsif ($action eq 'new_day' && $self->param_current_value('Created') == 1) {
        my $quest_param = $self->param_record('Days To Hold');
        $quest_param->current_value($quest_param->current_value-1);
        $quest_param->update;
        
        if ($quest_param->current_value == 0) {
            $self->status('Awaiting Reward');
            $self->update;    
        }
        
        return 1;
    }    
    
    return 0;
}

sub sector_to_create_in {
    my $self = shift;
    
    return $self->result_source->schema->resultset('Land')->find( $self->param_start_value('Location To Create') );
}

1;