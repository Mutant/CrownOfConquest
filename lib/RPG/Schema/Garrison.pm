package RPG::Schema::Garrison;

use Moose;

extends 'DBIx::Class';

__PACKAGE__->load_components(qw/Core Numeric/);
__PACKAGE__->table('Garrison');

__PACKAGE__->resultset_class('RPG::ResultSet::Garrison');

__PACKAGE__->add_columns(qw/garrison_id land_id party_id creature_attack_mode party_attack_mode flee_threshold in_combat_with gold name/);

__PACKAGE__->numeric_columns(qw/gold/);

__PACKAGE__->set_primary_key('garrison_id');

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', 'garrison_id', {cascade_delete => 0});

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', 'garrison_id', {cascade_delete => 0});

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id', {cascade_delete => 0} );

__PACKAGE__->belongs_to(
    'land',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' },
    {cascade_delete => 0}
);

with qw/
	RPG::Schema::Role::BeingGroup
	RPG::Schema::Role::CharacterGroup
/;

sub rank_separator_position {
	return 0;
}

sub members {
	my $self = shift;
	
	return $self->characters;	
}

sub group_type {
	return 'garrison';
}

sub number_alive {
    my $self = shift;

    return $self->result_source->schema->resultset('Character')->count(
        {
            hit_points => { '>', 0 },
            garrison_id   => $self->id,
        }
    );
}

sub after_land_move {
    my $self = shift;
    my $land = shift;    
}

sub current_location {
	my $self = shift;
	
	return $self->land;
}

sub find_fleeable_sectors {
    my $self = shift;
    my $base_point = {
    	x => $self->land->x,
    	y => $self->land->y	
    };
    
    # TODO: currently lets us get to sectors with adjacent towns... (where you can't create a garrison)

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->schema->resultset('Land'),
        relationship        => 'me',
        base_point          => $base_point,
        search_range        => 3,
        increment_search_by => 0,
        criteria => {
        	'town.town_id' => undef,
        	'orb.creature_orb_id'   => undef,
        	'garrison.garrison_id' => undef,
        },
        attrs => {
        	join => [qw/town orb garrison/],
        }
    );
}

sub in_combat {
	my $self = shift;
	
	return $self->in_combat_with ? 1 : 0;	
}

sub recent_battles_count {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Combat_Log')->get_logs_count_for_garrison($self);
}

sub is_online {
	return 0;
}

sub end_combat {
	my $self = shift;
	
	$self->in_combat_with(undef);
	$self->update;	
}

sub display_name {
	my $self = shift;
	my $exclude_party = shift // 0;
	
	my $party_name = $exclude_party ? '' : ' (' . $self->party->name . ')';
	
	return $self->name . $party_name if $self->name;
	
	my $land = $self->land;
	
	if ($land) {	
		return "The garrison at " . $land->x . ", " . $land->y . $party_name;
	}
	else {
		return "A garrison $party_name";
	}
}
	
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
	
1;