use strict;
use warnings;

package RPG::ResultSet::Character;

use base 'DBIx::Class::ResultSet';

use Carp;
use List::Util qw(max shuffle);
use File::Slurp;
use Games::Dice::Advanced;
use RPG::Maths;

sub generate_character {
    my $self        = shift;
    my %params      = @_;
    
    my $race        = $params{race}  || $self->result_source->schema->resultset('Race')->random;
    my $class       = $params{class} || $self->result_source->schema->resultset('Class')->random;
    my $level       = $params{level} // 1;
    my $roll_points = $params{roll_points} // 1;
    my $allocate_equipment = $params{allocate_equipment} // 0;
    
    if ($level > 1 && $roll_points == 0) {
        croak "Can only turn off rolling points for level 1 characters";   
    }
    
    my %levels = map { $_->level_number => $_->xp_needed } $self->result_source->schema->resultset('Levels')->search();
    my $max_level = max keys %levels;
    
    my $xp = 0;
    if ($level != 1) {
    	$xp = $self->_calculate_xp($level, $max_level, %levels);	
    }

    my %stats = (
        'strength'     => $race->base_str,
        'agility'      => $race->base_agl,
        'intelligence' => $race->base_int,
        'divinity'     => $race->base_div,
        'constitution' => $race->base_con,
    );

    my $stat_pool = RPG::Schema->config->{stats_pool};
    my $stat_max  = RPG::Schema->config->{stat_max};

    # Initial allocation of stat points
    %stats = $self->_allocate_stat_points( $stat_pool, $stat_max, $class->primary_stat, \%stats );

    # Yes, we're quite sexist
    my $gender = Games::Dice::Advanced->roll('1d3') > 1 ? 'male' : 'female';

    my $character = $self->create(
        {
            character_name => _generate_name($gender),
            class_id       => $class->id,
            race_id        => $race->id,
            level          => $level,
            xp             => $xp,
            party_order    => undef,
            gender         => $gender,
            %stats,
        }
    );

    # Roll for first level
    $character->roll_all if $roll_points;

    # Roll stats for all further levels above 1
    for ( 2 .. $level ) {
        $character->roll_all;

        %stats = $self->_allocate_stat_points( RPG::Schema->config->{stat_points_per_level}, undef, $class->primary_stat, \%stats );

        for my $stat ( keys %stats ) {
            $character->set_column( $stat, $stats{$stat} );
        }

        $character->update;
    }

    if ($roll_points) {
        $character->hit_points( $character->max_hit_points );
        $character->update;
    }
    
    if ($allocate_equipment) {
    	$self->_allocate_equipment($character);	
    }

    return $character;
}

sub _allocate_stat_points {
    my $self         = shift;
    my $stat_pool    = shift;
    my $stat_max     = shift;
    my $primary_stat = shift;
    my $stats        = shift;

    my @stats = keys %$stats;
    # Primary stat goes in multiple times to make it more likely to get added
    push @stats, $primary_stat if defined $primary_stat;

    # Allocate 1 point to a random stat until the pool is used
    while ( $stat_pool > 0 ) {
        my $stat = ( shuffle @stats )[0];

        # Make sure we dont exceed the stat max (if one was supplied)
        # TODO: possible infinite loop
        next if defined $stat_max && $stats->{$stat} == $stat_max;

        $stats->{$stat}++;

        $stat_pool--;
    }

    return %$stats;
}

my %names;

sub _generate_name {
    my $gender = shift;
    
    my $file_prefix = $gender eq 'male' ? '' : 'female_';
    
    unless ($names{$gender}) {
        @{$names{$gender}} = read_file( RPG::Schema->config->{data_file_path} . "/${file_prefix}character_names.txt" );
    }
    
    my @names = @{$names{$gender}};

    chomp @names;
    @names = shuffle @names;

    return $names[0];
}

sub _calculate_xp {
	my $self = shift;
	my $level = shift;
	my $max_level = shift;
	my %levels = @_;
	
	my $xp_for_next_level = ( $levels{ $level + 1 } || 0 );
	
	my $dice_size = $xp_for_next_level - $levels{$level};
	$dice_size = $levels{$level} if $level == $max_level;
	
    my $xp = $levels{$level} + Games::Dice::Advanced->roll( '1d' . $dice_size );
    
    return $xp;
}

sub _allocate_equipment {
    my $self      = shift;
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

    my @equip_places = $self->result_source->schema->resultset('Equip_Places')->search( 
    	{}, 
    	{ 
    		prefetch => { 'equip_place_categories' => 'item_category'}, 
    	}, 
    );

    foreach my $equip_place (@equip_places) {
        my @categories = map { $_->item_category } $equip_place->categories;

        if ( $equip_place->equip_place_name eq 'Left Hand' ) {
            @categories = $weapon{ $character->class->class_name };
        }
        elsif ( $equip_place->equip_place_name eq 'Right Hand' ) {
            next;
        }

        my @item_types = $self->result_source->schema->resultset('Item_Type')->search(
            {
                prevalence               => { '>=', $min_primary_prevalance, '<=', $max_primary_prevalance },
                'category.item_category' => \@categories,
            },
            { join => 'category', },
        );

        next unless @item_types;

        @item_types = shuffle @item_types;

		# TODO: generate enchanted items
        my $item = $self->result_source->schema->resultset('Items')->create( { item_type_id => $item_types[0]->id, } );

        $item->character_id( $character->id );
        $item->update;

        $item->equip_item( $equip_place->equip_place_name, 0 );
    }
}

1;
