package RPG::Schema::Building;

use Moose;
use Data::Dumper;

extends 'DBIx::Class';

use feature 'switch';

use RPG::ResultSet::RowsInSectorRange;

__PACKAGE__->load_components(qw/Core Numeric/);
__PACKAGE__->table('Building');

__PACKAGE__->resultset_class('RPG::ResultSet::Building');

__PACKAGE__->add_columns(qw/building_id land_id building_type_id owner_id owner_type name clay_needed stone_needed wood_needed iron_needed labor_needed/);

__PACKAGE__->numeric_columns(qw/clay_needed stone_needed wood_needed iron_needed labor_needed/);

__PACKAGE__->set_primary_key('building_id');

__PACKAGE__->belongs_to( 'building_type', 'RPG::Schema::Building_Type', 'building_type_id', {cascade_delete => 0} );

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' },
    {cascade_delete => 0}
);


sub upgrades_to {
	my $self = shift;
	return $self->{upgrades_to};
}
sub set_upgrades_to {
	my $self = shift;
	$self->{upgrades_to} = shift;
}

sub type {
	my $self = shift;
	return $self->{type};
}
sub set_type {
	my $self = shift;
	$self->{type} = shift;
}

sub class {
	my $self = shift;
	return $self->{'class'};
}
sub set_class {
	my $self = shift;
	$self->{class} = shift;
}

sub level {
	my $self = shift;
	return $self->{level};
}
sub set_level {
	my $self = shift;
	$self->{level} = shift;
}

sub image {
	my $self = shift;
	return $self->{image};
}
sub set_image {
	my $self = shift;
	$self->{image} = shift;
}

#  Get owner_name.  TODO: this is inefficient, should be joined but owner_id / owner_type needs a special join.
sub owner_name {
	my $self = shift;
	if (!defined $self->{owner_name}) {
	    given ($self->owner_type) {
	        when ('party') {
                my $party = $self->result_source->schema->resultset('Party')->find(
	        	  { 'party_id' => $self->owner_id, }
		        );
		        $self->{owner_name} = $party->name;
	        }
	        when ('kingdom') {
	            my $kingdom = $self->result_source->schema->resultset('Kingdom')->find(
	        	  { 'kingdom_id' => $self->owner_id, }
		        );
		        $self->{owner_name} = "The Kingdom of " . $kingdom->name;
	        }
	        default {
                $self->{owner_name} = "No one";
	        }
		}
	}
	return $self->{owner_name};
}

# Returns true if the entity passed in owns the building
sub owned_by {
    my $self = shift;
    my $entity = shift;
    
    my $type = $entity->group_type || 'kingdom';
    
    return 1 if $type eq $self->owner_type && $entity->id == $self->owner_id;
}

sub claim_land {
    my $self = shift;
    
    return unless $self->owner_type eq 'kingdom';
    
    my @sectors = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset    => $self->result_source->schema->resultset('Land'),
        relationship => 'me',
        base_point   => {
            x => $self->location->x,
            y => $self->location->y,
        },
        search_range        => $self->building_type->land_claim_range * 2 + 1,
        increment_search_by => 0,
    );
    
    foreach my $sector (@sectors) {
        # Skip sectors already claimed
        if (defined $sector->claimed_by_type && ($sector->claimed_by_type ne 'building' || $sector->claimed_by_id != $self->id)) {
            next;   
        } 
        
        $sector->kingdom_id($self->owner_id);
        $sector->claimed_by_id($self->id);
        $sector->claimed_by_type('building');
        $sector->update;
    } 
}

sub unclaim_land {
    my $self = shift;   
    
    my @sectors = $self->result_source->schema->resultset('Land')->search(
        {
            'claimed_by_id' => $self->id,
            'claimed_by_type' => 'building',   
        },
    );
    
    foreach my $sector (@sectors) {
        $sector->claimed_by_id(undef);
        $sector->claimed_by_type(undef);
        $sector->update;
    }     
}

1;
