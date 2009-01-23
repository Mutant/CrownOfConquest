use strict;
use warnings;

package RPG::NewDay::Recruitment;

use Data::Dumper;

use List::Util qw(max shuffle);
use Games::Dice::Advanced;

use RPG::Maths;
use File::Slurp;

# Package scope so everyone can read these
my ( $config, $schema, $logger, $new_day );

sub run {
    my $package = shift;
    $config = shift;
    $schema = shift;
    $logger = shift;
    $new_day = shift;

    my $town_rs = $schema->resultset('Town')->search( {}, { prefetch => { 'characters' => 'items' }, }, );

    while ( my $town = $town_rs->next ) {
        my @characters = $town->characters;

        my $ideal_number_of_characters = int( $town->prosperity / $config->{characters_per_prosperity} );
        $ideal_number_of_characters = 1 if $ideal_number_of_characters < 1;

        $logger->debug( 'Town id: ' . $town->id . " has " . scalar @characters . " characters, but should have $ideal_number_of_characters" );

        if ( scalar @characters < $ideal_number_of_characters ) {
            my $number_of_chars_to_create = $ideal_number_of_characters - scalar @characters;

            for ( 1 .. $number_of_chars_to_create ) {
                $package->generate_character($town);
            }
        }
    }
}

sub generate_character {
    my $package = shift;
    my $town    = shift;

    my $race  = $schema->resultset('Race')->random;
    my $class = $schema->resultset('Class')->random;

    my %levels = map { $_->level_number => $_->xp_needed } $schema->resultset('Levels')->search();
    my $max_level = max keys %levels;

    my $level = RPG::Maths->weighted_random_number( 1 .. $max_level );

    my $xp_for_next_level = ( $levels{ $level + 1 } || 0 );
    my $xp = $levels{$level} + int rand( $xp_for_next_level - $levels{$level} );

    my %stats = (
        'strength'     => $race->base_str,
        'agility'      => $race->base_agl,
        'intelligence' => $race->base_int,
        'divinity'     => $race->base_div,
        'constitution' => $race->base_con,
    );

    my $stat_pool = $config->{stats_pool};
    my $stat_max  = $config->{stat_max};

    # Initial allocation of stat points
    %stats = _allocate_stat_points( $stat_pool, $stat_max, $class->primary_stat, \%stats );

    my $character = $schema->resultset('Character')->create(
        {
            character_name => _generate_name(),
            class_id       => $class->id,
            race_id        => $race->id,
            town_id        => $town->id,
            level          => $level,
            xp             => $xp,
            party_order    => undef,
            %stats,
        }
    );

    for ( 1 .. $level ) {
        $character->roll_all;

        %stats = _allocate_stat_points( $config->{stat_points_per_level}, undef, $class->primary_stat, \%stats );

        for my $stat ( keys %stats ) {
            $character->set_column( $stat, $stats{$stat} );
        }

        $character->update;
    }

    $character->hit_points( $character->max_hit_points );
    $character->update;

    $character->set_default_spells;

    $package->_allocate_equipment($character);

    $schema->resultset('Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $new_day->id,
            event        => $character->character_name . " arrived at the town of " . $town->town_name . " and began looking for a party to join",
        },        
    );
}

sub _allocate_stat_points {
    my $stat_pool    = shift;
    my $stat_max     = shift;
    my $primary_stat = shift;
    my $stats        = shift;

    my @stats = keys %$stats;
    push @stats, $primary_stat;    # Primary stat goes in twice to make it more likely to get added

    # Allocate 1 point to a random stat until the pool is used
    while ( $stat_pool > 0 ) {
        my $stat = ( shuffle @stats )[0];

        # Make sure we dont exceed the stat max (if one was supplied)
        next if defined $stat_max && $stats->{$stat} == $stat_max;

        $stats->{$stat}++;

        $stat_pool--;
    }

    return %$stats;
}

my @names;

sub _generate_name {
    unless (@names) {
        @names = read_file( $ENV{RPG_HOME} . '/script/data/character_names.txt' );
    }

    chomp @names;
    @names = shuffle @names;

    return $names[0];
}

sub _allocate_equipment {
    my $package   = shift;
    my $character = shift;

    my %weapon = (
        'Warrior' => 'Melee Weapon',
        'Archer'  => 'Ranged Weapon',
        'Priest'  => 'Melee Weapon',
        'Mage'    => 'Melee Weapon',
    );

    my $min_primary_prevalance = 100 - $character->level * 10;

    my $max_primary_prevalance = 100 - ( $character->level - 4 ) * 10;
    $max_primary_prevalance = $min_primary_prevalance if $max_primary_prevalance < $min_primary_prevalance;
    $max_primary_prevalance = 40 if $max_primary_prevalance < 40;

    my @equip_places = $schema->resultset('Equip_Places')->search( {}, { prefetch => { 'equip_place_categories' => 'item_category' }, }, );

    foreach my $equip_place (@equip_places) {
        my @categories = map { $_->item_category } $equip_place->categories;

        if ( $equip_place->equip_place_name eq 'Left Hand' ) {
            @categories = $weapon{ $character->class->class_name };
        }
        elsif ( $equip_place->equip_place_name eq 'Right Hand' ) {
            next;
        }

        my @item_types = $schema->resultset('Item_Type')->search(
            {
                prevalence               => { '>=', $min_primary_prevalance, '<=', $max_primary_prevalance },
                'category.item_category' => \@categories,
            },
            { join => 'category', },
        );

        next unless @item_types;

        @item_types = shuffle @item_types;

        my $item = $schema->resultset('Items')->create( { item_type_id => $item_types[0]->id, } );

        $item->equip_item( $equip_place->equip_place_name, 0 );

        $item->character_id( $character->id );
        $item->update;
    }
}

1;

