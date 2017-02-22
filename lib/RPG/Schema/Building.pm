package RPG::Schema::Building;

use Moose;
use Data::Dumper;
use Carp;

extends 'DBIx::Class';

use RPG::ResultSet::RowsInSectorRange;

__PACKAGE__->load_components(qw/Core Numeric/);
__PACKAGE__->table('Building');

__PACKAGE__->resultset_class('RPG::ResultSet::Building');

__PACKAGE__->add_columns(qw/building_id land_id building_type_id owner_id owner_type name clay_needed stone_needed wood_needed iron_needed labor_needed/);

__PACKAGE__->numeric_columns(qw/clay_needed stone_needed wood_needed iron_needed labor_needed/);

__PACKAGE__->set_primary_key('building_id');

__PACKAGE__->belongs_to( 'building_type', 'RPG::Schema::Building_Type', 'building_type_id', { cascade_delete => 0 } );

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' },
    { cascade_delete    => 0 }
);

__PACKAGE__->has_many( 'upgrades', 'RPG::Schema::Building_Upgrade', 'building_id' );

with 'RPG::Schema::Role::Land_Claim';

sub claim_type { 'building' }

#  Get owner_name.  TODO: this is inefficient, should be joined but owner_id / owner_type needs a special join.
sub owner_name {
    my $self = shift;
    if ( !defined $self->{owner_name} ) {
        $self->{owner_name} = "No one";
        if ( $self->owner_type eq 'party' ) {
            my $party = $self->result_source->schema->resultset('Party')->find(
                { 'party_id' => $self->owner_id, }
            );
            $self->{owner_name} = $party->name;
        }
        elsif ( $self->owner_type eq 'kingdom' ) {
            my $kingdom = $self->result_source->schema->resultset('Kingdom')->find(
                { 'kingdom_id' => $self->owner_id, }
            );
            $self->{owner_name} = "The Kingdom of " . $kingdom->name;
        }
    }
    return $self->{owner_name};
}

sub owner {
    my $self = shift;

    if ( $self->owner_type eq 'party' ) {

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
    elsif ( $self->owner_type eq 'kingdom' ) {
        return $self->result_source->schema->resultset('Kingdom')->find(
            {
                'kingdom_id' => $self->owner_id,
            }
        );
    }
    elsif ( $self->owner_type eq 'town' ) {
        return $self->result_source->schema->resultset('Town')->find(
            {
                'town_id' => $self->owner_id,
            }
        );
    }
}

# Returns true if the entity passed in owns the building
sub owned_by {
    my $self   = shift;
    my $entity = shift;

    my $type = $entity->group_type || 'kingdom';

    return 1 if $type eq $self->owner_type && $entity->id == $self->owner_id;
}

sub kingdom {
    my $self = shift;

    return unless $self->owner_type eq 'kingdom';

    return $self->owner;
}

sub land_claim_range {
    my $self = shift;

    $self->building_type->land_claim_range;
}

sub get_bonus {
    my $self       = shift;
    my $bonus_type = shift;
    my $level      = shift;

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
        $level //= $upgrade->level - $upgrade->damage;

        $bonus = $level * $upgrade->type->modifier_per_level;
    }

    if ( $bonus_type eq 'defence_factor' ) {
        $bonus += $self->building_type->defense_factor;
    }

    return $bonus;
}

sub allowed_to_manage {
    my $self  = shift;
    my $party = shift;

    if ( $self->owner_type eq 'party' ) {
        if ( $self->owner_id == $party->id && $party->land_id == $self->land_id ) {
            return 1;
        }
    }

    if ( $self->owner_type eq 'town' ) {
        my $mayor = $self->owner->mayor;
        if ( $mayor && $mayor->party_id == $party->id ) {
            return 1;
        }
        else {
            return 0;
        }
    }

    if ( $self->owner_type eq 'kingdom' ) {
        return 0 if $party->land_id != $self->land_id;

        # Can manage building owned by the kingdom if they are the king, or have
        #  a garrison there, and are loyal to the kingdom
        return 0 if $party->kingdom_id != $self->owner_id;

        my $garrison = $self->result_source->schema->resultset('Garrison')->find(
            {
                land_id  => $self->land_id,
                party_id => $party->id,
            }
        );

        return 1 if $garrison;

        my $king = $self->owner->king;
        if ( $king && $king->party_id == $party->id ) {
            return 1;
        }

    }

    return 0;
}

1;
