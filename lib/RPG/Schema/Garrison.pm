package RPG::Schema::Garrison;

use Moose;

use feature 'switch';

extends 'DBIx::Class';

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Garrison');

__PACKAGE__->resultset_class('RPG::ResultSet::Garrison');

__PACKAGE__->add_columns(qw/garrison_id land_id party_id creature_attack_mode party_attack_mode flee_threshold in_combat_with gold name
                            attack_parties_from_kingdom attack_friendly_parties/);

__PACKAGE__->numeric_columns(qw/gold/);

__PACKAGE__->set_primary_key('garrison_id');

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', 'garrison_id', {cascade_delete => 0});

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', 'garrison_id', {cascade_delete => 0});

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id', {cascade_delete => 0} );

__PACKAGE__->has_many( 'messages', 'RPG::Schema::Garrison_Messages', 'garrison_id', );

__PACKAGE__->belongs_to(
    'land',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' },
    {cascade_delete => 0, join_type => 'LEFT OUTER'}
);

__PACKAGE__->has_many('item_sectors', 'RPG::Schema::Item_Grid', {'foreign.owner_id' => 'self.garrison_id'}, { where => { owner_type => 'garrison' } });

with qw/
	RPG::Schema::Role::BeingGroup
	RPG::Schema::Role::CharacterGroup
	RPG::Schema::Role::Item_Grid
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

sub check_for_fight {
	my $self        = shift;
	my $opponent    = shift;
	
	my $attack_mode = $opponent->group_type eq 'creature_group' ? $self->creature_attack_mode : $self->party_attack_mode;
	
	return 0 if $attack_mode eq 'Defensive Only';

	if ($opponent->group_type eq 'party') {
	    # Don't attack low-level parties
	    return 0 if $opponent->level < RPG::Schema->config->{min_party_level_for_garrison_attack};
	    
	    # Don't attack own party
	    return 0 if $opponent->party_id == $self->party_id;
	    
	    # Don't attack parties from own kingdom, unless instructed to do so
	    my $party = $self->party;
	    if ($party->kingdom_id && ! $self->attack_parties_from_kingdom && $party->kingdom_id == $opponent->kingdom_id) {
	       return 0;   
	    }
	    
	    # Don't attack parties from kingdoms at peace with garrison's kingdom, unless instructed to do so
	    if ($party->kingdom_id && ! $self->attack_friendly_parties) {
            my $relationship = $party->kingdom->relationship_with($opponent->kingdom_id);
            return 0 if $relationship && $relationship->type eq 'peace';
	    }
	}
	
	return 1 if $attack_mode eq 'Attack All Opponents';

	my $factor = $opponent->compare_to_party($self);

	given ($attack_mode) {
		when ( 'Attack Weaker Opponents' ) {		     
			return 1 if $factor > 20;
		}
		when ( 'Attack Similar Opponents' ) {
			return 1 if $factor > 5;
		}
		when ( 'Attack Stronger Opponents' ) {
			return 1 if $factor > -20;
		}
	}

	return 0;
}

around 'get_equipment' => sub {
    my $orig = shift;
    my $self = shift;
    my $category = shift;
    
    my @equipment = $self->$orig($category);
    
	my @garrison_equipment = $self->search_related(
        'items',
    	{
    	    'category.item_category' => $category,
    	},
        {
            prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
        },
	);
	
	return (@equipment, @garrison_equipment);   
};

sub organise_equipment {
    my $self = shift;
    
    my @items = $self->search_related('items',
        {},
        {
            prefetch => {'item_type' => 'category'},
            order_by => 'category.item_category, me.item_id',            
        }
    );        
    
    $self->organise_items_in_tabs({ owner_type => 'garrison', width => 8, height => 8, max_tabs => 5, allow_empty_tabs => 1}, @items);
}
	
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
	
1;