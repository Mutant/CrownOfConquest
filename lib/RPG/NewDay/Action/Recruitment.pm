package RPG::NewDay::Action::Recruitment;

use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;

use List::Util qw(max shuffle);
use Games::Dice::Advanced;

use RPG::Maths;
use File::Slurp;

sub depends { qw/RPG::NewDay::Action::CreateDay/ };

sub run {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search( {}, { prefetch => { 'characters' => 'items' }, }, );

    while ( my $town = $town_rs->next ) {
        my @characters = $town->characters;

        my $ideal_number_of_characters = int( $town->prosperity / $c->config->{characters_per_prosperity} );
        $ideal_number_of_characters = 1 if $ideal_number_of_characters < 1;

        if ( scalar @characters < $ideal_number_of_characters ) {
            $c->logger->debug( 'Town id: ' . $town->id . " has " . scalar @characters . " characters, but should have $ideal_number_of_characters" );
            
            my $number_of_chars_to_create = $ideal_number_of_characters - scalar @characters;

            for ( 1 .. $number_of_chars_to_create ) {
                $self->generate_character($town);
            }
        }
    }
}

sub generate_character {
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    my $race  = $c->schema->resultset('Race')->random;
    my $class = $c->schema->resultset('Class')->random;

    my %levels = map { $_->level_number => $_->xp_needed } $c->schema->resultset('Levels')->search();
    my $max_level = max keys %levels;

    my $level = RPG::Maths->weighted_random_number( 1 .. $max_level );

	my $xp = $self->calculate_xp($level, $max_level, %levels);

    my $character = $c->schema->resultset('Character')->generate_character($race, $class, $level, $xp);
    
    $character->set_default_spells;
    
    $character->town_id($town->id);
    $character->update;
    
    $self->_allocate_equipment($character);

    $c->schema->resultset('Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $c->current_day->id,
            event        => $character->character_name . " arrived at the town of " . $town->town_name . " and began looking for a party to join",
        },
    );
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

    my $c = $self->context;

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

    my @equip_places = $c->schema->resultset('Equip_Places')->search( {}, { prefetch => { 'equip_place_categories' => 'item_category' }, }, );

    foreach my $equip_place (@equip_places) {
        my @categories = map { $_->item_category } $equip_place->categories;

        if ( $equip_place->equip_place_name eq 'Left Hand' ) {
            @categories = $weapon{ $character->class->class_name };
        }
        elsif ( $equip_place->equip_place_name eq 'Right Hand' ) {
            next;
        }

        my @item_types = $c->schema->resultset('Item_Type')->search(
            {
                prevalence               => { '>=', $min_primary_prevalance, '<=', $max_primary_prevalance },
                'category.item_category' => \@categories,
            },
            { join => 'category', },
        );

        next unless @item_types;

        @item_types = shuffle @item_types;

        my $item = $c->schema->resultset('Items')->create( { item_type_id => $item_types[0]->id, } );

        $item->equip_item( $equip_place->equip_place_name, 0 );

        $item->character_id( $character->id );
        $item->update;
    }
}

1;

