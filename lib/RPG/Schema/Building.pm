package RPG::Schema::Building;

use Moose;
use Data::Dumper;
use Carp;

extends 'DBIx::Class';

use RPG::ResultSet::RowsInSectorRange;

use feature 'switch';

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

__PACKAGE__->has_many( 'upgrades', 'RPG::Schema::Building_Upgrade', 'building_id' );

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

sub owner {
    my $self = shift;
    
    given ($self->owner_type) {
        when ('party') {
            # If there's a garrison in the sector, the garrison is considered owner
            my $garrison = $self->result_source->schema->resultset('Garrison')->find(
                {
                    land_id => $self->land_id,
                }
            );
            
            return $garrison if $garrison;            
            
            return $self->result_source->schema->resultset('Party')->find(
	           { 
	               'party_id' => $self->owner_id, 
	           }
            );
        }
        when ('kingdom') {
            return $self->result_source->schema->resultset('Kingdom')->find(
                { 
                    'kingdom_id' => $self->owner_id, 
                }
            );           
        }
        when ('town') {
            return $self->result_source->schema->resultset('Town')->find(
                { 
                    'town_id' => $self->owner_id, 
                }
            );            
        }
    }
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

sub get_bonus {
    my $self = shift;
    my $bonus_type = shift;
    my $level = shift;

    my $upgrade_type = RPG::Schema::Building_Upgrade_Type->upgrade_type_for_bonus($bonus_type);

    croak "No such bonus type: $bonus_type" unless $upgrade_type;
    
    my $upgrade = $self->find_related(
        'upgrades',
        {
            'type.name' => $upgrade_type,
        },
        {
            prefetch => 'type',
        }
    );

    my $bonus = 0;
    
    if ($upgrade) {
        $level //= $upgrade->level;
            
        $bonus = $level * $upgrade->type->modifier_per_level;
    }
        
    if ($bonus_type eq 'defence_factor') {
        $bonus += $self->building_type->defense_factor;
    }        
    
    return $bonus;
}

1;
