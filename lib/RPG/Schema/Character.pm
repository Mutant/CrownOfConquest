use strict;
use warnings;

package RPG::Schema::Character;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;
use List::Util qw(sum);

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('`Character`');

__PACKAGE__->add_columns(
    qw/character_id character_name class_id race_id strength intelligence agility divinity constitution hit_points
        level spell_points max_hit_points party_id party_order last_combat_action stat_points town_id/
);

__PACKAGE__->add_columns( xp => { accessor => '_xp' } );

__PACKAGE__->set_primary_key('character_id');

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

__PACKAGE__->belongs_to( 'class', 'RPG::Schema::Class', { 'foreign.class_id' => 'self.class_id' } );

__PACKAGE__->belongs_to( 'race', 'RPG::Schema::Race', { 'foreign.race_id' => 'self.race_id' } );

__PACKAGE__->has_many(
    'items', 'RPG::Schema::Items',
    { 'foreign.character_id' => 'self.character_id' },
    { prefetch               => [ 'item_type', 'item_variables' ], },
);

__PACKAGE__->has_many( 'memorised_spells', 'RPG::Schema::Memorised_Spells', { 'foreign.character_id' => 'self.character_id' }, );

__PACKAGE__->many_to_many( 'spells' => 'memorised_spells', 'spell' );

__PACKAGE__->has_many( 'character_effects', 'RPG::Schema::Character_Effect', { 'foreign.character_id' => 'self.character_id' }, );

our @STATS = qw(str con int div agl);

sub roll_all {
    my $self = shift;

    my %rolls;

    $rolls{hit_points} = $self->roll_hit_points;

    if ( $self->class->class_name eq 'Mage' ) {
        $rolls{magic_points} = $self->roll_spell_points;
    }
    elsif ( $self->class->class_name eq 'Priest' ) {
        $rolls{faith_points} = $self->roll_spell_points;
    }

    $self->update;

    return %rolls;
}

# Calcuates the point bonus for a stat (e.g. hit points, magic points).
# If called as a class method, takes the value of the stat as first parameter
# If called as instance method, takes the name of the stat
sub point_bonus {
    my $self = shift;

    my $stat_value = shift || $self->get_column(shift);

    return int $stat_value / RPG::Schema->config->{'point_dividend'};
}

# Rolls hit points for the next level.
# If called as a class method, first parameter is level, second is class, third is value of con
sub roll_hit_points {
    my $self = shift;

    my $class;
    if ( ref $self ) {
        $class = $self->class->class_name;
    }
    else {
        $class = shift;
    }

    my $point_max = RPG::Schema->config->{level_hit_points_max}{$class};

    if ( ref $self ) {
        my $points = $self->_roll_points( 'constitution', $point_max );
        $self->max_hit_points( $self->max_hit_points + $points );

        if ( $self->level == 1 ) {
            $self->hit_points($points);
        }

        return $points;
    }
    else {
        my $level = shift || croak 'Level not supplied';
        my $con   = shift || croak 'Consitution not supplied';
        return $self->_roll_points( $level, $con, $point_max );
    }
}

sub roll_spell_points {
    my $self = shift;

    my $point_max = RPG::Schema->config->{level_spell_points_max};
    my $point_min = RPG::Schema->config->{level_spell_points_min};

    if ( ref $self ) {
        return unless $self->class->class_name eq 'Priest' || $self->class->class_name eq 'Mage';

        my $stat = $self->class->class_name eq 'Priest' ? 'divinity' : 'intelligence';

        my $points = $self->_roll_points( $stat, $point_max, $point_min );

        $self->spell_points( $self->spell_points + $points );

        return $points;
    }

    else {
        my $level = shift || croak 'Level not supplied';
        my $div   = shift || croak 'Stat value not supplied';
        return $self->_roll_points( $level, $div, $point_max, $point_min );
    }
}

sub _roll_points {
    my $self = shift;

    my ( $level, $stat );

    if ( ref $self ) {
        $level = $self->level;
        $stat  = $self->get_column(shift);
    }
    else {
        $level = shift || croak 'Level not supplied';
        $stat  = shift || croak 'Stat not supplied';
    }

    my $point_max = shift || croak 'point_max not supplied';
    my $point_min = shift || 1;

    if ( $point_max < $point_min ) {
        my $message = "Can't roll stats where max is less than min (min: $point_min, max: $point_max, level: $level, stat: $stat";

        if ( ref $self ) {
            $message .= ", character: " . $self->character_name . ", id: " . $self->id;
        }

        $message .= ")";

        confess($message);
    }

    my $points = $level == 1 ? $point_max : Games::Dice::Advanced->roll( '1d' . ( $point_max - $point_min ) ) + ( $point_min - 1 );

    $points += $self->point_bonus($stat);

    return $points;
}

# Set the default spells for a new char (if they're of the appropriate class)
sub set_default_spells {
    my $self = shift;

    return unless $self->class->class_name eq 'Priest' || $self->class->class_name eq 'Mage';

    # Get all the spells for this class, sorted by points ascending
    my @spells = $self->result_source->schema->resultset('Spell')->search(
        {
            class_id => $self->class->id,
            hidden   => 0,
        },
        { order_by => 'points', },
    );

    my $spell_points_used = 0;

    while ( $spell_points_used < $self->spell_points ) {
        foreach my $spell (@spells) {
            last if $self->spell_points < $spell_points_used + $spell->points;

            my $memorised_spell = $self->result_source->schema->resultset('Memorised_Spells')->find_or_create(
                {
                    character_id      => $self->id,
                    spell_id          => $spell->id,
                    memorised_today   => 1,
                    memorise_tomorrow => 1,
                },
            );

            $memorised_spell->memorise_count( $memorised_spell->memorise_count + 1 );
            $memorised_spell->memorise_count_tomorrow( $memorised_spell->memorise_count_tomorrow + 1 );
            $memorised_spell->update;

            $spell_points_used += $spell->points;
        }
    }
}

sub attack_factor {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    # Assume only one weapon equipped.
    # TODO needs to change to support multiple weapons
    my $item = shift @items;

    # TODO possibly should be in the DB
    my $af_attribute = 'strength';
    $af_attribute = $item->item_type->category->item_category eq 'Ranged Weapon' ? 'agility' : 'strength'
        if $item;

    my $attack_factor = $self->get_column($af_attribute);

    if ($item) {

        # Add in item AF
        $attack_factor += $item->attribute('Attack Factor')->item_attribute_value || 0;

        # Subtract back rank penalty if necessary
        $attack_factor -= $item->attribute('Back Rank Penalty') && $item->attribute('Back Rank Penalty')->item_attribute_value || 0
            unless $self->in_front_rank;
            
        # Add in upgrade bonus
        $attack_factor += $item->variable("Attack Factor Upgrade");
    }

    # Apply effects
    my $effect_df = 0;
    map { $effect_df += $_->effect->modifier if $_->effect->modified_stat eq 'attack_factor' } $self->character_effects;
    $attack_factor += $effect_df;

    return $attack_factor;
}

sub defence_factor {
    my $self = shift;

    my @items = $self->get_equipped_item('Armour');

    my $armour_df = 0;
    map { $armour_df += $_->attribute('Defence Factor')->item_attribute_value + ($_->variable('Defence Factor Upgrade') || 0) } @items;

    # Apply effects
    my $effect_df = 0;
    map { $effect_df += $_->effect->modifier if $_->effect->modified_stat eq 'defence_factor' } $self->character_effects;
    
    return $self->agility + $armour_df + $effect_df;
}

=head1 damage

Max damage the character can do with the weapon they currently have equipped

=cut

sub damage {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    # Assume only one weapon equipped.
    # TODO needs to change to support multiple weapons
    my $weapon = shift @items;

    # Apply effects
    my $effect_dam = 0;
    map { $effect_dam += $_->effect->modifier if $_->effect->modified_stat eq 'damage' } $self->character_effects;
    return 2 + $effect_dam unless $weapon;    # nothing equipped, assume bare hands

    return $weapon->attribute('Damage')->item_attribute_value + $weapon->variable('Damage Upgrade') + $effect_dam;
}

sub weapon {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    # Assume only one weapon equipped.
    # TODO needs to change to support multiple weapons
    my $item = shift @items;

    return $item ? $item->item_type->item_type : 'Bare Hands';
}

=head2 get_equipped_item($super_category)

Returns a list of any equipped item records for a specified super category.

=cut

sub get_equipped_item {
    my $self = shift;
    my $category = shift || croak 'Category not supplied';

    return @{ $self->{equipped_item}{$category} } if ref $self->{equipped_item}{$category} eq 'ARRAY';

    my @items = $self->result_source->schema->resultset('Items')->search(
        {
            'character_id'                       => $self->id,
            'super_category.super_category_name' => $category,
        },
        {
            'join'     => [ 'equipped_in', ],
            'prefetch' => [ { item_type => { 'item_attributes' => 'item_attribute_name' } }, { 'item_type' => { 'category' => 'super_category' } }, ],
        },
    );

    $self->{equipped_item}{$category} = \@items;

    return @items;
}

sub hit {
    my $self   = shift;
    my $damage = shift;

    my $new_hp_total = $self->hit_points - $damage;
    $new_hp_total = 0 if $new_hp_total < 0;

    $self->hit_points($new_hp_total);
    $self->update;
}

sub name {
    my $self = shift;
    return $self->character_name;
}

sub is_dead {
    my $self = shift;

    return $self->hit_points <= 0 ? 1 : 0;
}

=head2 equipped_items(@items)

Returns a hashref keyed by equip places, with the character's item equipped in that place as the value

If the list of items isn't passed in, it will be read from the DB.

=cut

sub equipped_items {
    my $self  = shift;
    my @items = @_;

    my @equip_places = $self->result_source->schema->resultset('Equip_Places')->search;

    @items = $self->items unless @items;

    my %equipped_items;

    # Character has no items
    unless (@items) {
        %equipped_items = map { $_->equip_place_name => undef } @equip_places;
        return \%equipped_items;
    }

    foreach my $equip_place (@equip_places) {

        # Should only have one item equipped in a particular place
        my ($item) = grep { $_->equip_place_id && $equip_place->id == $_->equip_place_id; } @items;

        #warn $equip_place->equip_place_name . " " . $item->item_type->item_type if $item;
        $equipped_items{ $equip_place->equip_place_name } = $item;
    }

    #warn Dumper \%equipped_items;

    return \%equipped_items;
}

sub is_character {
    return 1;
}

# Execute an attack, mainly just make sure there is ammo for ranged weapons, and deduct one from quantity
sub execute_attack {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    foreach my $item (@items) {
        if ( $item->item_type->category->item_category eq 'Ranged Weapon' ) {
            my $ammunition_item_type_id = $item->item_type->attribute('Ammunition')->value;

            # Get all appropriate ammunition this character has
            my @ammo = $self->search_related( 'items', { 'me.item_type_id' => $ammunition_item_type_id, }, { prefetch => 'item_variables', }, );

            return { no_ammo => 1 } unless @ammo;    # Didn't find anything, so return - they can't attack!

            # Find the first ammo item and
            foreach my $ammo (@ammo) {
                my $quantity = $ammo->variable('Quantity');

                if ( $quantity - 1 == 0 ) {

                    # None left, delete this item
                    $ammo->delete;
                }
                else {
                    $ammo->variable( 'Quantity', $quantity - 1 );
                }

                last;
            }
        }
    }
}

# Accessor for xp. If xp updated, also checks if the character should be leveled up. If it should, returns a hash of details
#  of the stats/points gained
sub xp {
    my $self   = shift;
    my $new_xp = shift;

    return $self->_xp unless $new_xp;

    $self->_xp($new_xp);

    # Check if we should level up
    my $level_rec = $self->result_source->schema->resultset('Levels')->find( { level_number => $self->level + 1, }, );

    if ( ref $level_rec && $new_xp > $level_rec->xp_needed ) {
        $self->level( $self->level + 1 );

        my %rolls = $self->roll_all;

        # Add stat points
        $self->stat_points( $self->stat_points + RPG::Schema->config->{stat_points_per_level} );
        $rolls{stat_points} = RPG::Schema->config->{stat_points_per_level};

        return \%rolls;
    }
}

sub resurrect_cost {
    my $self = shift;

    # TODO: cost should be modified by the town's prosperity

    return $self->level * RPG::Schema->config->{resurrection_cost};
}

# Number of prayer or magic points used for spells memorised tomorrow
#  Takes optional parameter of a spell to *exclude* from this count
sub spell_points_used {
    my $self             = shift;
    my $exclude_spell_id = shift;

    my %where;
    if ($exclude_spell_id) {
        $where{'spell_id'} = { '!=', $exclude_spell_id };
    }

    my $result = $self->result_source->schema->resultset('Memorised_Spells')->find(
        {
            character_id      => $self->id,
            memorise_tomorrow => 1,
            %where,
        },
        {
            join   => 'spell',
            select => [ { sum => 'spell.points * memorise_count_tomorrow' } ],
            as     => 'total_points',
        },
    );

    return $result->get_column('total_points') || 0;
}

sub rememorise_spells {
    my $self = shift;

    my @spells_to_memorise = $self->memorised_spells;

    my $spell_count = 0;

    foreach my $spell (@spells_to_memorise) {
        if ( $spell->memorise_tomorrow ) {
            $spell->memorised_today(1);
            $spell->memorise_count( $spell->memorise_count_tomorrow );
            $spell->number_cast_today(0);
            $spell->update;

            $spell_count += $spell->memorise_count_tomorrow;
        }
        else {

            # Spell no longer memorised, so delete the record
            $spell->delete;
        }
    }

    return $spell_count;
}

sub change_hit_points {
    my $self   = shift;
    my $amount = shift;

    return if $self->is_dead;

    my $actual_amount = $amount;

    # Reduce amount if it would take us beyond the maximum hit points
    if ( $self->max_hit_points < $amount + $self->hit_points ) {
        $actual_amount = $self->max_hit_points - $self->hit_points;
    }

    $self->hit_points( $self->hit_points + $actual_amount );

    return $actual_amount;
}

# Returns true if character is in the front rank
sub in_front_rank {
    my $self = shift;

    # If character isn't in a party, say they're in the front rank
    return 1 unless $self->party_id;

    return $self->party->rank_separator_position > $self->party_order;
}

# Return the number of attacks allowed by this character
sub number_of_attacks {
    my $self           = shift;
    my @attack_history = @_;

    my $number_of_attacks = 1;

    # Modifier is number of extra attacks per round
    #  i.e. 1 = 2 attacks per round, 0.5 = 2 attacks every 3 rounds
    my $modifier = 0;

    # Check for Archer's second attack, which applies an extra modifier
    # TODO: currently hardcoded class name and item category, but could be in the DB
    if ( $self->class->class_name eq 'Archer' ) {
        my @weapons = $self->get_equipped_item('Weapon');

        my $ranged_weapons = grep { $_->item_type->category->item_category eq 'Ranged Weapon' } @weapons;

        $modifier += 0.5 if $ranged_weapons >= 1;
    }

    # Check for any attack_frequency effects
    my $extra_modifier_from_effects = $self->effect_value('attack_frequency') || 0;
    $modifier += $extra_modifier_from_effects;

    # Any whole numbers are added on to number of attacks
    my $whole_extra_attacks = int $modifier;
    $number_of_attacks += $whole_extra_attacks;

    # Find out the decimal if any, and decide whether another attack should occur this round
    $modifier = $modifier - $whole_extra_attacks;

    # If there's a modifier, and an attack history exists, figure out if there should be another extra attack this round.
    #  (If there's no history, we start with the smaller amount of attacks)
    if ( $modifier > 0 && @attack_history ) {

        # Figure out number of attacks they should've had in recent rounds
        my $expected_attacks = int 1 / $modifier;

        # Figure out how far to look back
        my $lookback = $expected_attacks - 1;
        $lookback = scalar @attack_history if $lookback > scalar @attack_history;

        my @recent = splice @attack_history, -$lookback;

        my $count = sum @recent;

        if ( $count < $expected_attacks + $whole_extra_attacks * $lookback ) {
            $number_of_attacks++;
        }
    }

    return $number_of_attacks;
}

sub effect_value {
    my $self = shift;
    my $effect = shift || croak "Effect not supplied";

    my $modifier;
    map { $modifier += $_->effect->modifier if $_->effect->modified_stat eq $effect } $self->character_effects;

    return $modifier;
}

sub value {
    my $self = shift;

    return $self->{value} if defined $self->{value};

    my $value = int 150 + $self->xp * 0.8;
    $value += int $self->hit_points;
    $value += int $self->spell_points;

    foreach my $item ( $self->items ) {
        $value += int $item->item_type->base_cost * 0.8;
    }

    $self->{value} = $value;

    return $self->{value};
}

sub sell_value {
    my $self = shift;

    return int $self->value * 0.8;
}

my %starting_equipment = (
    'Warrior' => [ 'Short Sword', 'Wooden Shield' ],
    'Archer'  => [ 'Sling',       'Sling Stones' ],
    'Priest'  => [ 'Short Sword', 'Wooden Shield' ],
    'Mage'    => [ 'Dagger',      'Wooden Shield' ],
);

sub set_starting_equipment {
    my $self = shift;

    my $schema = $self->result_source->schema;

    foreach my $starting_item ( @{ $starting_equipment{ $self->class->class_name } } ) {
        my $item_type = $schema->resultset('Item_Type')->find( { item_type => $starting_item } );

        my $item = $schema->resultset('Items')->create( { item_type_id => $item_type->id, } );

        $item->add_to_characters_inventory($self);

        if ( $item->variable('Quantity') ) {
            $item->variable( 'Quantity', 20 );
        }
    }
}

1;
