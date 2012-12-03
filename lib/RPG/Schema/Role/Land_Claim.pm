package RPG::Schema::Role::Land_Claim;

use Moose::Role;

requires qw/kingdom claim_type location result_source id land_claim_range/;

sub claim_land {
    my $self = shift;
    
    my $kingdom = $self->kingdom;
        
    return unless $kingdom;
    
    my @sectors = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset    => $self->result_source->schema->resultset('Land'),
        relationship => 'me',
        base_point   => {
            x => $self->location->x,
            y => $self->location->y,
        },
        search_range        => $self->land_claim_range * 2 + 1,
        increment_search_by => 0,
        include_base_point => 1,
    );
    
    foreach my $sector (@sectors) {
        # Skip sectors already claimed
        if (defined $sector->claimed_by_type && ($sector->claimed_by_type ne $self->claim_type || $sector->claimed_by_id != $self->id)) {
            next;   
        } 
        
        $sector->kingdom_id($kingdom->id);
        $sector->claimed_by_id($self->id);
        $sector->claimed_by_type($self->claim_type);
        $sector->update;
    }    
}

sub unclaim_land {
    my $self = shift;   
    
    my @sectors = $self->result_source->schema->resultset('Land')->search(
        {
            'claimed_by_id' => $self->id,
            'claimed_by_type' => $self->claim_type,   
        },
    );
    
    foreach my $sector (@sectors) {
        $sector->claimed_by_id(undef);
        $sector->claimed_by_type(undef);
        $sector->update;
    }     
}

1;