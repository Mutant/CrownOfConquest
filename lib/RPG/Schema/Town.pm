use strict;
use warnings;

package RPG::Schema::Town;

use base 'DBIx::Class';

use Carp;

use Moose;

use Math::Round qw(round);
use RPG::ResultSet::RowsInSectorRange;
use RPG::Maths;

__PACKAGE__->load_components(qw/Numeric InflateColumn::DateTime Core/);
__PACKAGE__->table('Town');

__PACKAGE__->resultset_class('RPG::ResultSet::Town');

__PACKAGE__->add_columns( qw/town_id town_name land_id prosperity blacksmith_age blacksmith_skill
      discount_type discount_value discount_threshold pending_mayor gold peasant_tax
      party_tax_level_step base_party_tax sales_tax tax_modified_today
      mayor_rating peasant_state last_election advisor_fee character_heal_budget
      trap_level/ );

__PACKAGE__->add_columns(
    pending_mayor_date => { data_type => 'datetime' },
);

__PACKAGE__->numeric_columns(
    peasant_tax => {
        min_value => 0,
        max_value => 100,
    },
    gold => {
        min_value => 0,
    },
    party_tax_level_step => {
        min_value => 0,
        max_value => 100,
    },
    base_party_tax => {
        min_value => 0,
        max_value => 100,
    },
    sales_tax => {
        min_value => 0,
        max_value => 20,
    },
    mayor_rating => {
        min_value => -100,
        max_value => 100,
    },
    prosperity => {
        min_value => 1,
        max_value => 100,
    },
    advisor_fee => {
        min_value => 0,
    },
    trap_level => {
        min_value => 0,
        max_value => 10,
    },
    blacksmith_skill => {
        min_value => 0,
        max_value => 25,
      }
);

__PACKAGE__->set_primary_key('town_id');

__PACKAGE__->has_many( 'shops', 'RPG::Schema::Shop', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->has_many( 'quests', 'RPG::Schema::Quest', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->has_many( 'party_town', 'RPG::Schema::Party_Town', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->might_have( 'castle', 'RPG::Schema::Dungeon', { 'foreign.land_id' => 'self.land_id' }, { 'where' => { 'type' => 'castle' } } );

__PACKAGE__->might_have( 'sewer', 'RPG::Schema::Dungeon', { 'foreign.land_id' => 'self.land_id' }, { 'where' => { 'type' => 'sewer' } } );

__PACKAGE__->might_have( 'mayor', 'RPG::Schema::Character', { 'foreign.mayor_of' => 'self.town_id' }, );

__PACKAGE__->has_many( 'history', 'RPG::Schema::Town_History', 'town_id', );

__PACKAGE__->has_many( 'elections', 'RPG::Schema::Election', 'town_id', );

__PACKAGE__->might_have( 'current_election', 'RPG::Schema::Election', 'town_id', { where => { 'status' => 'Open' } } );

__PACKAGE__->might_have( 'building', 'RPG::Schema::Building', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'capital_of', 'RPG::Schema::Kingdom', { 'foreign.capital' => 'self.town_id' }, );

__PACKAGE__->has_many( 'guards', 'RPG::Schema::Town_Guards', 'town_id', );

__PACKAGE__->has_many( 'raids', 'RPG::Schema::Town_Raid', 'town_id', );

with 'RPG::Schema::Role::Land_Claim';

sub claim_type { 'town' }

sub label {
    my $self = shift;

    return $self->town_name . ' (' . $self->location->x . ', ' . $self->location->y . ')';
}

sub tax_cost {
    my $self           = shift;
    my $party          = shift;
    my $base_cost      = shift;
    my $level_modifier = shift;

    my $party_level;
    my $prestige = 0;

    my $mayor = $self->mayor;
    if ( ref $party && $mayor && defined $mayor->party_id && $mayor->party_id == $party->id ) {
        return { mayor => 1 };
    }

    if ( ref $party ) {
        my $party_town_rec = $self->find_related( 'party_town', { 'party_id' => $party->id, }, );

        if ( $party_town_rec && $party_town_rec->tax_amount_paid_today > 0 ) {
            return { paid => 1 };
        }

        $party_level = $party->level;
        $prestige = $party_town_rec->prestige if $party_town_rec;
    }
    else {
        $party_level = $party;
    }

    if ( !defined $base_cost && !defined $level_modifier ) {
        if ( $mayor && $mayor->party_id ) {
            $base_cost      = $self->base_party_tax;
            $level_modifier = $self->party_tax_level_step;
        }
        else {
            $base_cost = $self->prosperity * RPG::Schema->config->{tax_per_prosperity};
            $level_modifier = $self->prosperity * RPG::Schema->config->{tax_level_modifier};
        }
    }

    my $level_cost = round( $level_modifier * ( $party_level - 1 ) );

    my $prestige_modifier = ( 0 - $prestige ) / 300;

    my $negotiation_modifier = 1;
    if ( ref $party ) {
        my $negotiation_skill = $party->skill_aggregate( 'Negotiation', 'town_entrance_tax' );
        $negotiation_modifier = 1 - ( $negotiation_skill / 100 );
    }

    my $gold_cost = round( ( $base_cost + $level_cost ) * $negotiation_modifier );
    $gold_cost += round( $gold_cost * $prestige_modifier );
    $gold_cost = 1 if $gold_cost < 1;

    my $turn_cost = round $gold_cost / RPG::Schema->config->{tax_turn_divisor};

    $turn_cost = 1 if $turn_cost < 1;

    return {
        gold  => $gold_cost,
        turns => $turn_cost,
    };
}

sub land_claim_range {
    my $self = shift;

    return RPG::Schema->config->{town_land_claim_range};
}

sub has_road_to {
    my $self      = shift;
    my $dest_town = shift;

    my $found_town = 0;

    return $self->_find_roads( $self->location, $dest_town->location );
}

sub kingdom {
    my $self = shift;

    my $location = $self->location;

    return $location->kingdom;
}

sub _find_roads {
    my $self         = shift;
    my $start_sector = shift;
    my $dest_sector  = shift;
    my $checked      = shift || {};

    $checked->{ $start_sector->id } = 1;

    my @surround_sectors = $self->result_source->schema->resultset('Land')->search_for_adjacent_sectors(
        $start_sector->x,
        $start_sector->y,
        3,
        3,
    );

    my @connected_sectors;
    foreach my $sector (@surround_sectors) {
        next if $checked->{ $sector->id };

        if ( $start_sector->has_road_joining_to($sector) ) {
            if ( $sector->id == $dest_sector->id ) {
                return 1;
            }

            push @connected_sectors, $sector;
        }
    }

    foreach my $connected_sector (@connected_sectors) {
        return 1 if $self->_find_roads( $connected_sector, $dest_sector, $checked );
    }

    return 0;
}

sub take_sales_tax {
    my $self = shift;
    my $cost = shift;

    my $towns_cut = int( $cost * $self->sales_tax / 100 );
    $self->increase_gold($towns_cut);
    $self->add_to_history(
        {
            type    => 'income',
            value   => $towns_cut,
            message => 'Sales Tax',
            day_id => $self->result_source->schema->resultset('Day')->find_today->id,
        }
    );
}

sub inn_cost {
    my $self = shift;
    my $character = shift || confess "Character not supplied";

    return int( $self->prosperity / 10 * $character->level / 4 ) + 15;
}

sub expected_garrison_chars_level {
    my $self = shift;

    my $expected_garrison_chars_level = 0;
    $expected_garrison_chars_level = 30  if $self->prosperity > 25;
    $expected_garrison_chars_level = 100 if $self->prosperity > 45;
    $expected_garrison_chars_level = 150 if $self->prosperity > 65;
    $expected_garrison_chars_level = 200 if $self->prosperity > 85;

    return $expected_garrison_chars_level;
}

sub heal_cost_per_hp {
    my $self = shift;

    return round( RPG::Schema->config->{min_healer_cost} + ( 100 - $self->prosperity ) / 100 * RPG::Schema->config->{max_healer_cost} );
}

sub change_allegiance {
    my $self        = shift;
    my $new_kingdom = shift;

    my $location    = $self->location;
    my $old_kingdom = $location->kingdom;

    return if $new_kingdom && $old_kingdom && $new_kingdom->id == $old_kingdom->id;

    $location->kingdom_id( $new_kingdom ? $new_kingdom->id : undef );
    $location->update;
    $self->discard_changes;

    if ( !$new_kingdom ) {
        $self->unclaim_land;
    }
    else {
        $self->claim_land;
    }
    $self->update;

    my $today = $self->result_source->schema->resultset('Day')->find_today;

    # check if this is the most towns the kingdom has had
    if ( $new_kingdom && $new_kingdom->highest_town_count < $new_kingdom->towns->count ) {
        $new_kingdom->highest_town_count( $new_kingdom->towns->count );
        $new_kingdom->highest_town_count_day_id( $today->id );
        $new_kingdom->update;
    }

    # Leave messages for old/new kings
    if ($new_kingdom) {
        $new_kingdom->add_to_messages(
            {
                message => "The town of " . $self->town_name . " is now loyal to our kingdom.",
                day_id => $today->id,
                type   => 'public_message',
            }
        );
    }
    if ($old_kingdom) {
        my $message = "The town of " . $self->town_name . " is no longer loyal to our kingdom.";

        # Remove as capital (if it was)
        if ( $old_kingdom->capital && $old_kingdom->capital == $self->id ) {
            $old_kingdom->change_capital(undef);
            $message .= ' We no longer have a capital!';
        }

        $old_kingdom->add_to_messages(
            {
                message => $message,
                day_id  => $today->id,
                type    => 'public_message',
            }
        );

    }
}

sub decline_mayoralty {
    my $self = shift;

    $self->pending_mayor(undef);
    $self->add_to_history(
        {
            type => 'news',
            message => 'There is currently no mayor. The town is under martial law.',
            day_id => $self->result_source->schema->resultset('Day')->find_today->id,
        }
    );
}

sub kingdom_loyalty {
    my $self = shift;

    return unless $self->location->kingdom_id;

    my $kingdom_town = $self->result_source->schema->resultset('Kingdom_Town')->find_or_create(
        {
            kingdom_id => $self->location->kingdom_id,
            town_id    => $self->id,
        }
    );

    return $kingdom_town->loyalty;
}

# Add in Kingdom_Town records for all active kingdoms
sub create_kingdom_town_recs {
    my $self = shift;

    my @kingdoms = $self->result_source->schema->resultset('Kingdom')->search(
        {
            active => 1,
        }
    );

    foreach my $kingdom (@kingdoms) {
        $self->result_source->schema->resultset('Kingdom_Town')->find_or_create(
            {
                kingdom_id => $kingdom->id,
                town_id    => $self->id,
            }
        );
    }
}

# Check if a party is allowed to enter a town
sub party_can_enter {
    my $self  = shift;
    my $party = shift;

    my $party_town = $self->result_source->schema->resultset('Party_Town')->find_or_create(
        {
            party_id => $party->id,
            town_id  => $self->id,
        },
    );

    my $reason;

    # Check if they have really low prestige, and need to be refused.
    my $mayor = $self->mayor;
    if ( !$mayor || $mayor->party_id != $party->id ) {
        my $prestige_threshold = -90 + round( $self->prosperity / 25 );
        if ( ( $party_town->prestige // 0 ) <= $prestige_threshold ) {

            $reason = "You've are not allowed into " . $self->town_name . ". You'll need to wait until your prestige improves before they'll let you in";
        }
    }

    # Check if the mayor's party has an IP address in common
    if ( $mayor && !$mayor->is_npc && $party->is_suspected_of_coop_with( $mayor->party ) ) {
        $reason = "You cannot enter " . $self->town_name . " as the mayor's party has IP addresses in common with yours";
    }

    return ( $reason ? 0 : 1, $reason );
}

sub blacksmith_skill_label {
    my $self = shift;

    if ( $self->blacksmith_skill < 3 ) {
        return 'terrible';
    }
    elsif ( $self->blacksmith_skill < 6 ) {
        return 'poor';
    }
    elsif ( $self->blacksmith_skill < 9 ) {
        return 'average';
    }
    elsif ( $self->blacksmith_skill < 12 ) {
        return 'average';
    }
    elsif ( $self->blacksmith_skill < 15 ) {
        return 'good';
    }
    elsif ( $self->blacksmith_skill < 18 ) {
        return 'excellent';
    }
    elsif ( $self->blacksmith_skill < 21 ) {
        return 'amazing';
    }
    else {
        return 'god-like';
    }
}

# Return the relationship state between the kingdoms of this town and the passed in party
sub kingdom_relationship_between_party {
    my $self  = shift;
    my $party = shift;
    my $from_party = shift // 1; # Whether the relationship is from the party's point of view, or the towns

    return if !$party->kingdom_id || !$self->location->kingdom_id;

    my $from_kingdom = $from_party ? $party->kingdom : $self->location->kingdom;
    my $to_kingdom_id = $from_party ? $self->location->kingdom_id : $party->kingdom_id;

    my $relationship = $from_kingdom->relationship_with($to_kingdom_id);

    return unless $relationship;

    return $relationship->type;
}

# Return a hash with the defences of this town
sub defences {
    my $self = shift;

    my $mayor    = $self->mayor;
    my @garrison = $self->result_source->schema->resultset('Character')->search(
        {
            status         => 'mayor_garrison',
            status_context => $self->id,
        },
    );
    my $building = $self->building;

    my @guards = $self->guards;

    return (
        mayor      => $mayor,
        garrison   => \@garrison,
        building   => $building,
        trap_level => $self->trap_level,
        guards     => \@guards,
    );
}

sub coaches {
    my $self    = shift;
    my $party   = shift;
    my $town_id = shift;

    my @towns;
    if ($town_id) {
        my $town = $self->result_source->schema->resultset('Town')->find(
            {
                town_id => $town_id,
            }
        );
        @towns = ($town);
    }
    else {
        @towns = $self->result_source->schema->resultset('Town')->find_in_range(
            {
                x => $self->location->x,
                y => $self->location->y,
            },
            RPG::Schema->config()->{town_coach_range} * 2 + 1,
        );
    }

    my @coaches;
    foreach my $town (@towns) {
        my $coach_town_x = $town->location->x;
        my $coach_town_y = $town->location->y;

        my $distance = RPG::Map->get_distance_between_points(
            {
                x => $self->location->x,
                y => $self->location->y,
            },
            {
                x => $coach_town_x,
                y => $coach_town_y,
            },
        );

        my ( $can_enter, $reason ) = $town->party_can_enter($party);

        my $relationship = $town->kingdom_relationship_between_party( $party, 0 ) // '';
        if ( $can_enter && $relationship eq 'war' ) {
            $can_enter = 0;
            $reason = "You cannot take a coach to a town that your kingdom is at war with";
        }

        push @coaches, {
            town     => $town,
            distance => $distance,
            gold_cost => ( $distance * RPG::Schema->config()->{town_coach_gold_cost} )
              + ( $party->level * RPG::Schema->config()->{town_coach_party_level_gold_cost} ),
            turn_cost => int( $distance * RPG::Schema->config()->{town_coach_turn_cost} ),
            tax       => $town->tax_cost($party),
            can_enter => $can_enter,
            reason    => $reason,
        };
    }

    return @coaches;
}

1;
