package RPG::Schema::Kingdom;
use base 'DBIx::Class';
use strict;
use warnings;

use DBIx::Class::ResultClass::HashRefInflator;

use RPG::Exception;
use Math::Round qw(round);

__PACKAGE__->load_components(qw/Numeric InflateColumn::DateTime Core/);
__PACKAGE__->table('Kingdom');

__PACKAGE__->add_columns( qw/kingdom_id name colour mayor_tax gold active inception_day_id fall_day_id
      highest_land_count highest_land_count_day_id highest_town_count highest_town_count_day_id
      highest_party_count highest_party_count_day_id capital description majesty has_crown majesty_rank/ );

__PACKAGE__->set_primary_key('kingdom_id');

__PACKAGE__->numeric_columns(
    mayor_tax => {
        min_value => 1,
        max_value => 25,
    },
    gold => {
        min_value => 0,
    },
    qw/highest_land_count highest_town_count highest_party_count/,
);

__PACKAGE__->add_columns(
    majesty_leader_since => { data_type => 'datetime' },
);

__PACKAGE__->has_many( 'parties', 'RPG::Schema::Party', 'kingdom_id', { where => { defunct => undef } } );
__PACKAGE__->has_many( 'quests',  'RPG::Schema::Quest', 'kingdom_id' );
__PACKAGE__->has_many( 'sectors', 'RPG::Schema::Land',  'kingdom_id' );
__PACKAGE__->has_many( 'messages', 'RPG::Schema::Kingdom_Messages', 'kingdom_id' );
__PACKAGE__->has_many( 'party_kingdoms', 'RPG::Schema::Party_Kingdom', 'kingdom_id', { join_type => 'LEFT OUTER' } );
__PACKAGE__->has_many( 'town_loyalty', 'RPG::Schema::Kingdom_Town', 'kingdom_id' );
__PACKAGE__->has_many( 'relationships', 'RPG::Schema::Kingdom_Relationship', 'kingdom_id' );
__PACKAGE__->has_many( 'claims', 'RPG::Schema::Kingdom_Claim', 'kingdom_id' );

__PACKAGE__->belongs_to( 'inception_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.inception_day_id' } );
__PACKAGE__->belongs_to( 'fall_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.fall_day_id' } );
__PACKAGE__->belongs_to( 'highest_land_count_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.highest_land_count_day_id' } );
__PACKAGE__->belongs_to( 'highest_town_count_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.highest_town_count_day_id' } );
__PACKAGE__->belongs_to( 'highest_party_count_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.highest_party_count_day_id' } );

__PACKAGE__->belongs_to( 'king', 'RPG::Schema::Character',
    {
        'foreign.status_context' => 'self.kingdom_id',
    },
    {
        'where' => { 'status' => 'king' },
    },
);

__PACKAGE__->belongs_to( 'capital_city', 'RPG::Schema::Town', { 'foreign.town_id' => 'self.capital' } );
__PACKAGE__->has_many( 'capital_history', 'RPG::Schema::Capital_History', 'kingdom_id' );

__PACKAGE__->has_many( 'buildings', 'RPG::Schema::Building', { 'foreign.owner_id' => 'self.kingdom_id' }, { where => { 'owner_type' => 'kingdom' } } );

my @colours = (
    'Silver',
    'Gray',
    'Black',
    'Maroon',
    'Olive',
    'Blue',
    'Navy',
    'Chocolate',
    'BurlyWood',
    'Crimson',
    'Green',
    'Firebrick',
    'steelblue',
);

sub colours { @colours }

sub quests_allowed {
    my $self = shift;

    my $land_count = $self->sectors->count;

    my $quest_count = round $land_count / RPG::Schema->config->{land_per_kingdom_quests};

    my $king = $self->king;
    my $leadership_bonus = $king->execute_skill( 'Leadership', 'kingdom_quests_allowed' ) // 0;

    $quest_count += $leadership_bonus;

    $quest_count = RPG::Schema->config->{minimum_kingdom_quests} if $quest_count < RPG::Schema->config->{minimum_kingdom_quests};

    return $quest_count;
}

sub towns {
    my $self = shift;

    return $self->result_source->schema->resultset('Town')->search(
        {
            'location.kingdom_id' => $self->id,
        },
        {
            join => 'location',
        }
    );
}

sub duration {
    my $self = shift;

    return if !$self->inception_day_id;

    my $fall_day = $self->fall_day_id ? $self->fall_day : $self->result_source->schema->resultset('Day')->find_today;

    return $fall_day->day_number - $self->inception_day->day_number;
}

# Find the sectors that are part of a kingdom's border.
#  Not terribly effcient, so probably should only be called offline
# Note, only sectors with no sector to the top, bottom, left or right are considered on the border.
#  Sectors can't be borders on the diagonal
# The edge of the world is considered a border if the method is passed a true value
sub border_sectors {
    my $self = shift;
    my $edge_of_world_is_border = shift // 0;

    my $sectors_rs = $self->sectors;

    $sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my @sectors;
    my $grid;
    while ( my $sector = $sectors_rs->next ) {
        push @sectors, $sector;
        $grid->{ $sector->{x} }{ $sector->{y} } = 1;
    }

    my @border_sectors;
    my %world_range;
    foreach my $sector (@sectors) {
        if ( !$edge_of_world_is_border ) {
            %world_range = $self->result_source->schema->resultset('Land')->get_x_y_range()
              unless %world_range;

            # Ignore any sectors that are only missing neighbouring sectors on the edge of the world
            if ( $sector->{x} == $world_range{min_x} ) {
                $grid->{ $sector->{x} - 1 }{ $sector->{y} } = 1;
            }
            if ( $sector->{x} == $world_range{max_x} ) {
                $grid->{ $sector->{x} + 1 }{ $sector->{y} } = 1;
            }
            if ( $sector->{y} == $world_range{min_y} ) {
                $grid->{ $sector->{x} }{ $sector->{y} - 1 } = 1;
            }
            if ( $sector->{y} == $world_range{max_y} ) {
                $grid->{ $sector->{x} }{ $sector->{y} + 1 } = 1;
            }
        }

        if ( $grid->{ $sector->{x} - 1 }{ $sector->{y} } and $grid->{ $sector->{x} }{ $sector->{y} + 1 }
            and $grid->{ $sector->{x} + 1 }{ $sector->{y} } and $grid->{ $sector->{x} }{ $sector->{y} - 1 } ) {
            next;
        }

        push @border_sectors, $sector;
    }

    return @border_sectors;

}

sub move_capital_cost {
    my $self = shift;

    my $capital_count = $self->capital_history->count;

    return 0 if $capital_count <= 0;

    my $land_size = $self->sectors->count;

    my $cost = RPG::Schema->config->{capital_move_cost_per_sector} * $land_size;

    return $cost;
}

sub change_capital {
    my $self           = shift;
    my $new_capital_id = shift;

    if ($new_capital_id) {
        my $cost = $self->move_capital_cost;
        die RPG::Exception->new(
            type    => 'insufficient_gold',
            message => 'Not enough gold to change the capital',
        ) if $self->gold < $cost;

        $self->decrease_gold($cost);
    }

    $self->capital($new_capital_id);
    $self->update;

    my $today = $self->result_source->schema->resultset('Day')->find_today();

    # Set end date of old capital (if there is one)
    my $old_capital_history = $self->find_related(
        'capital_history',
        {
            end_date => undef,
        }
    );
    if ($old_capital_history) {
        $old_capital_history->end_date( $today->day_id );
        $old_capital_history->update;
    }

    if ($new_capital_id) {
        $self->add_to_capital_history(
            {
                town_id    => $new_capital_id,
                start_date => $today->id,
            }
        );

        $self->add_to_messages(
            {
                message => "The capital has been moved to " . $self->capital_city->town_name,
                day_id => $today->id,
            }
        );

    }
}

sub relationship_list {
    my $self = shift;

    my @kingdoms = $self->result_source->schema->resultset('Kingdom')->search(
        {
            kingdom_id => { '!=', $self->id },
            active => 1,
        }
    );

    my %relationships_by_kingdom = map { $_->with_id => $_ } $self->search_related(
        'relationships',
        {
            ended => undef,
        },
        {
            prefetch => 'with_kingdom',
        }
    );

    my @relationships;
    foreach my $kingdom (@kingdoms) {
        my $relationship = $relationships_by_kingdom{ $kingdom->id };

        if ( !$relationship ) {
            $relationship = $self->add_to_relationships(
                {
                    with_id => $kingdom->id,
                    type    => 'neutral',
                }
            );
        }

        push @relationships, $relationship;
    }

    return @relationships;
}

sub relationship_with {
    my $self    = shift;
    my $with_id = shift;

    return if $with_id == $self->id;

    my $relationship = $self->find_related( 'relationships',
        {
            with_id => $with_id,
            ended   => undef,
        }
    );

    return $relationship;
}

sub current_claim {
    my $self = shift;

    return $self->find_related(
        'claims',
        {
            outcome => undef,
        }
    );
}

# Return true if the party passed in has made a recent claim
#  for the throne
sub party_made_recent_claim {
    my $self  = shift;
    my $party = shift;

    my $claim_count = $self->search_related(
        'claims',
        {
            'claimant.party_id' => $party->id,
            claim_made => { '>=', DateTime->now->subtract( days => RPG::Schema->config->{failed_claim_ban_period} ) },
        },
        {
            join => 'claimant',
        }
    )->count;

    return $claim_count > 0 ? 1 : 0;
}

# Return true if the party can make a claim to the throne
sub party_can_claim_throne {
    my $self  = shift;
    my $party = shift;

    return 0 if $party->level < RPG::Schema->config->{minimum_kingdom_level};

    my $king = $self->king;

    return 0 if !$king || !$king->is_npc;

    return 0 if $self->current_claim;

    return 0 if $self->party_made_recent_claim($party);

    return 1;
}

sub calculate_majesty_score {
    my $self = shift;

    my $party_count    = $self->parties->count;
    my $land_count     = $self->sectors->count;
    my $building_count = $self->buildings->count;
    my $town_count = $self->result_source->schema->resultset('Town')->search(
        {
            'location.kingdom_id' => $self->id,
        },
        {
            'join' => 'location',
        }
    )->count;

    #warn "Party: $party_count, Land: $land_count, Building: $building_count, Town: $town_count\n";

    return round( $party_count + ( $land_count / 100 ) + ( $building_count * 2 ) + $town_count );
}

sub majesty_leader_since_string {
    my $self = shift;

    return unless $self->majesty_leader_since;

    return RPG::DateTime->time_since_datetime_detailed( $self->majesty_leader_since, 0 );
}

1;
