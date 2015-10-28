package RPG::C::Town::Sage;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use Data::Dumper;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use Math::Round qw(round);
use HTML::Strip;

sub auto : Private {
    my ( $self, $c ) = @_;
    
    unless ( $c->stash->{party_location}->town ) {
        $c->error("Not in a town!");
        return 0;
    }
    
    return 1;
}    
    

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward('main');
}

sub main : Local {
    my ( $self, $c ) = @_;

    my @item_types = $c->model('DBIC::Item_Type')->search(
        { 'category.hidden' => 0, },
        {
            join     => 'category',
            order_by => 'item_type',
        },
    );

    my @dungeon_levels_allowed_to_enter;
    for my $level ( 1 .. $c->config->{dungeon_max_level} ) {
        if ( RPG::Schema::Dungeon->party_can_enter( $level, $c->stash->{party} ) ) {
            push @dungeon_levels_allowed_to_enter, $level;
        }
    }

    my $costs = $c->forward( 'calculate_costs', [ $c->stash->{party_location}->town ] );
    
    my $vial = $c->model('DBIC::Item_Type')->find(
        {
            item_type => 'Vial of Dragons Blood',
        }
    );
    
    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/sage.html',
                params   => {
                    %$costs,
                    party                           => $c->stash->{party},
                    item_types                      => \@item_types,
                    dungeon_levels_allowed_to_enter => \@dungeon_levels_allowed_to_enter,
                    town                            => $c->stash->{party_location}->town,
                    vial                            => $vial,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages',       $panel ];
    push @{ $c->stash->{refresh_panels} }, [ 'popup-messages', $c->stash->{messages} ];

    $c->forward('/panel/refresh');
}

sub calculate_costs : Private {
    my ( $self, $c, $town ) = @_;

    my %costs = (
        direction_cost              => $c->config->{sage_direction_cost},
        distance_cost               => $c->config->{sage_distance_cost},
        location_cost               => $c->config->{sage_location_cost},
        item_find_cost              => $c->config->{sage_item_find_cost},
        find_dungeon_cost_per_level => $c->config->{sage_find_dungeon_cost_per_level},
        base_orb_cost               => $c->config->{sage_find_orb_base_cost},
        orb_level_step              => $c->config->{sage_find_orb_level_step},
    );

    if ( $town->discount_type eq 'sage' && $c->stash->{party}->prestige_for_town($town) >= $town->discount_threshold ) {
        while ( my ( $cost_type, $cost ) = each %costs ) {
            $costs{$cost_type} = round( $cost * ( 100 - $town->discount_value ) / 100 );
        }
    }

    my $book = $c->model('DBIC::Item_Type')->find(
        {
            item_type => 'Book of Past Lives',
        }
    );    
    
    my %book_costs;
    for my $book_max_level (keys %{$c->config->{book_of_past_live_cost_modifiers}}) {
        $book_costs{$book_max_level} = $book->base_cost * $c->config->{book_of_past_live_cost_modifiers}{$book_max_level} 
            * $c->config->{sage_book_cost_modifier};   
    }
    
    $costs{book_costs} = \%book_costs;
    
    return \%costs;
}

sub find_town : Local {
    my ( $self, $c ) = @_;

    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};

    my $message;
    my $error;

    eval {
        my $costs = $c->forward( 'calculate_costs', [ $party_location->town ] );

        my $cost = $costs->{ $c->req->param('find_type') . '_cost' };

        die { error => "Invalid find_type: " . $c->req->param('find_type') }
            unless defined $cost;

        die { message => "You don't have enough money for that!" }
            unless $party->gold > $cost;

        my $town_to_find = $c->model('DBIC::Town')->find( { town_name => $c->req->param('town_name'), }, { prefetch => 'location', }, );

        die { message => "I don't know of a town called " . $c->req->param('town_name') }
            unless $town_to_find;

        die { message => "You're already in " . $town_to_find->town_name . "!" }
            if $town_to_find->id == $party_location->town->id;

        if ( $c->req->param('find_type') eq 'direction' ) {
            my $direction = RPG::Map->get_direction_to_point(
                {
                    x => $party_location->x,
                    y => $party_location->y,
                },
                {
                    x => $town_to_find->location->x,
                    y => $town_to_find->location->y,
                },
            );

            $message = "The town of " . $town_to_find->town_name . " is to the $direction of here";
        }
        if ( $c->req->param('find_type') eq 'distance' ) {
            my $distance = RPG::Map->get_distance_between_points(
                {
                    x => $party_location->x,
                    y => $party_location->y,
                },
                {
                    x => $town_to_find->location->x,
                    y => $town_to_find->location->y,
                },
            );

            $message = "The town of " . $town_to_find->town_name . " is $distance sectors from here";
        }
        if ( $c->req->param('find_type') eq 'location' ) {

            $message =
                  "The town of "
                . $town_to_find->town_name
                . " can be found at sector "
                . $town_to_find->location->x . ", "
                . $town_to_find->location->y;

            $message .= ". The town has been added to your map";

            $c->model('DBIC::Mapped_Sectors')->find_or_create(
                {
                    party_id => $party->id,
                    land_id  => $town_to_find->location->id,
                },
            );
        }

        $party->gold( $party->gold - $cost );
        $party->update;
    };
    if ($@) {
        if ( ref $@ eq 'HASH' ) {
            my %excep = %{$@};
            $message = $excep{message};
            $error   = $excep{error};
        }
        else {
            die $@;
        }
    }

    $c->stash->{messages} = $message;
    $c->error($error);

    push @{ $c->stash->{refresh_panels} }, ('party_status');

    $c->forward('/town/sage/main');
}

sub find_item : Local {
    my ( $self, $c ) = @_;

    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};

    my $message;

    unless ( $party->gold >= $c->config->{sage_item_find_cost} ) {
        $message = "You don't have enough gold to do that!";
    }
    else {
        my $item_type = $c->model('DBIC::Item_Type')->find( { item_type_id => $c->req->param('item_type_to_find'), } );

        unless ($item_type) {
            $message = "I don't know of that item type";
        }
        else {
            my @towns_with_item_type = $c->model('DBIC::Town')->search(
                { 'items_in_shop.item_type_id' => $item_type->id, },
                {
                    join     => { 'shops' => 'items_in_shop' },
                    prefetch => 'location',
                },
            );

            unless (@towns_with_item_type) {
                $message = "I don't know of anywhere that has that item";
            }
            else {
                my $closest_town;
                my $min_distance;

                foreach my $town_to_check (@towns_with_item_type) {
                    my $dist = RPG::Map->get_distance_between_points(
                        {
                            x => $party_location->x,
                            y => $party_location->y,
                        },
                        {
                            x => $town_to_check->location->x,
                            y => $town_to_check->location->y,
                        },
                    );

                    if ( !$min_distance || $dist < $min_distance ) {
                        $closest_town = $town_to_check;
                    }
                }

                $message = "There is currently a " . $item_type->item_type . " in " . $closest_town->town_name;

                my $costs = $c->forward( 'calculate_costs', [ $party_location->town ] );

                $party->gold( $party->gold - $costs->{item_find_cost} );
                $party->update;
            }
        }
    }

    $c->stash->{messages} = $message;

    push @{ $c->stash->{refresh_panels} }, ('party_status');

    $c->forward('/town/sage/main');
}

sub find_dungeon : Local {
    my ( $self, $c ) = @_;

    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};

    my $message = eval {
        my $level = $c->req->param('find_level') || croak "Level not defined";

        unless ( RPG::Schema::Dungeon->party_can_enter( $level, $party ) ) {
            return "You're not high enough level to find a dungeon of that level";
        }

        my $costs = $c->forward( 'calculate_costs', [ $party_location->town ] );

        my $cost = $costs->{find_dungeon_cost_per_level} * $level;

        if ( $party->gold < $cost ) {
            return "You don't have enough gold to do that!";
        }

        # Find a dungeon within range
        my ( $top, $bottom ) = RPG::Map->surrounds_by_range(
            $party_location->town->location->x,
            $party_location->town->location->y,
            $c->config->{sage_dungeon_find_range}
        );

        my @dungeons = $c->model('DBIC::Dungeon')->search(
            {
                'location.x' => { '>=', $top->{x}, '<=', $bottom->{x} },
                'location.y' => { '>=', $top->{y}, '<=', $bottom->{y} },
                level        => $level,
                type => 'dungeon',
            },
            { prefetch => ['location'] }
        );

        unless (@dungeons) {
            return "Sorry, I don't know of any nearby dungeons of that level";
        }

        # See if any of these dungeons are unknown to the party
        my $dungeon_to_find;
        foreach my $dungeon ( shuffle @dungeons ) {
            my $mapped_sector = $c->model('DBIC::Mapped_Sector')->find(
            	{
	                party_id => $party->id,
	                land_id  => $dungeon->land_id,
            	}
            );

            if ($mapped_sector && ! $mapped_sector->known_dungeon) {
                $dungeon_to_find = $dungeon;
                last;
            }
        }

        unless ($dungeon_to_find) {
            return "Sorry, you already know about all the nearby dungeons of that level";
        }

        # Add to mapped sectors
        my $mapped_sector = $c->model('DBIC::Mapped_Sectors')->find_or_create(
            {
                land_id  => $dungeon_to_find->land_id,
                party_id => $party->id,

            }
        );
        
		$mapped_sector->known_dungeon($dungeon_to_find->level);
		$mapped_sector->update;

        # Deduct money
        $party->gold( $c->stash->{party}->gold - $cost );
        $party->update;

        return
              "A level "
            . $c->req->param('find_level')
            . " dungeon can be found at "
            . $dungeon_to_find->location->x . ", "
            . $dungeon_to_find->location->y;
    };
    if ($@) {

        # Rethrow execptions
        die $@;
    }

    $c->stash->{messages} = $message;

    push @{ $c->stash->{refresh_panels} }, ('party_status');

    $c->forward('/town/sage/main');
}

sub find_orb : Local {
    my ( $self, $c ) = @_;
    
    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};    
   
    my $hs = HTML::Strip->new();
    
    my $clean_orb = $hs->parse( $c->req->param('orb_name') );    

    my $message = eval {
        if (! $c->req->param('orb_name') || ! $c->req->param('amount_to_spend')) {
            return "Please enter an orb name and an amount to spend";
        }
        
        my $orb = $c->model('DBIC::Creature_Orb')->find(
            {
                name => $c->req->param('orb_name'),
                land_id => {'!=', undef},
            },
            {
                prefetch => 'land',
            }
        );


        if (! $orb) {
            return "I don't know of any Orbs with the name " . $clean_orb;
        }
        
        if ($c->req->param('amount_to_spend') > $party->gold) {
            return "You do not have enough gold";
        }
                      
        my $costs = $c->forward( 'calculate_costs', [ $party_location->town ] );

        my $min_orb_cost = $orb->level * $costs->{base_orb_cost} + (($orb->level-1) * $costs->{orb_level_step});
            
        if ($c->req->param('amount_to_spend') < $min_orb_cost) {
            return "I cannot find the Orb of $clean_orb for such a small amount";
        }
        
        $party->decrease_gold($c->req->param('amount_to_spend'));
        $party->update;
        
        my $inaccuracy = 6 - round($min_orb_cost / $c->req->param('amount_to_spend'));
        $inaccuracy = 1 if $inaccuracy < 1;
        
        my %world_range = $c->model('DBIC::Land')->get_x_y_range();
        
        my $x = $orb->land->x + round($inaccuracy/2) - Games::Dice::Advanced->roll('1d'.$inaccuracy);
        $x = $world_range{min_x} if $x < $world_range{min_x};
        $x = $world_range{max_x} if $x > $world_range{max_x};
        
        my $y = $orb->land->y + round($inaccuracy/2) - Games::Dice::Advanced->roll('1d'.$inaccuracy);
        $y = $world_range{min_y} if $x < $world_range{min_y};
        $y = $world_range{max_y} if $x > $world_range{max_y};
        
        return "The Orb of $clean_orb is in or around the sector $x, $y";
    };
    if ($@) {
        # Rethrow execptions
        die $@;
    }    
    
    $c->stash->{messages} = $message;

    push @{ $c->stash->{refresh_panels} }, ('party_status');

    $c->forward('/town/sage/main');    
    
}

sub buy_vial : Local {
    my ( $self, $c ) = @_;
    
    my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters_in_party;
    
    croak "Invalid character" unless $character;
    
    my $vial = $c->model('DBIC::Item_Type')->find(
        {
            item_type => 'Vial of Dragons Blood',
        }
    );    
    
    my $cost = $c->req->param('quantity') * $vial->base_cost;
    
    if ($c->stash->{party}->gold < $cost) {
        $c->stash->{messages} = "You do not have enough gold to buy the vials";
    }
    else {
        $c->stash->{party}->decrease_gold($cost);
        $c->stash->{party}->update;
        
        my $vial_item = $c->model('DBIC::Items')->create(
            {
                item_type_id => $vial->id,
            }
        );
        $vial_item->variable('Quantity', $c->req->param('quantity'));
        $vial_item->add_to_characters_inventory($character);
    }
    
    push @{ $c->stash->{refresh_panels} }, ('party_status');

    $c->forward('/town/sage/main');    
}

sub buy_book : Local {
    my ( $self, $c ) = @_;
    
    my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters_in_party;
    
    croak "Invalid character" unless $character;
    
    my $book = $c->model('DBIC::Item_Type')->find(
        {
            item_type => 'Book of Past Lives',
        }
    );
    
    my $required_max_level = 30;
    if ($character->level <= 10) {
        $required_max_level = 10;
    }
    elsif ($character->level <= 20) {
        $required_max_level = 20;
    }
    
    my $costs = $c->forward( 'calculate_costs', [ $c->stash->{party_location}->town ] );
    
    my $cost = $costs->{book_costs}{$required_max_level};
    
    if ($c->stash->{party}->gold < $cost) {
        $c->stash->{messages} = "You do not have enough gold to buy the book";
    }
    else {
        $c->stash->{party}->decrease_gold($cost);
        $c->stash->{party}->update;
        
        my $book_item = $c->model('DBIC::Items')->create(
            {
                item_type_id => $book->id,
            }
        );
        $book_item->variable('Max Level', $required_max_level);
        $book_item->add_to_characters_inventory($character);
    }
    
    $c->stash->{party}->discard_changes;
    
    push @{ $c->stash->{refresh_panels} }, ('party_status', 'party');
    
    $c->stash->{messages} = 'The book has been purchased';

    $c->forward('/town/sage/main');    
}

1;
