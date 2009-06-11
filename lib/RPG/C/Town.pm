package RPG::C::Town;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature qw(switch);

use Math::Round qw(round);
use JSON;
use List::Util qw(shuffle);
use Carp;

sub main : Local {
    my ( $self, $c, $return_output ) = @_;

    my $parties_in_sector = $c->forward( '/party/parties_in_sector', [ $c->stash->{party_location}->id ] );

    $c->forward('/party/party_messages_check');

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/main.html',
                params   => {
                    town              => $c->stash->{party_location}->town,
                    day_logs          => $c->stash->{day_logs},
                    party_messages    => $c->stash->{party_messages},
                    parties_in_sector => $parties_in_sector,
                },
                return_output => $return_output || 0,
            }
        ]
    );
}

sub back_to_main : Local {
    my ( $self, $c ) = @_;

    my $panel = $c->forward( 'main', [1] );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub shop_list : Local {
    my ( $self, $c ) = @_;

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'town/shop_list.html',
                params        => { town => $c->stash->{party_location}->town, },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub healer : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @characters = $c->stash->{party}->characters;

    my ( $cost_to_heal, @dead_chars ) = _get_party_health( $town, @characters );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/healer.html',
                params   => {
                    cost_to_heal    => $cost_to_heal,
                    dead_characters => \@dead_chars,
                    town            => $town,
                    messages        => $c->stash->{messages},
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub heal_party : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @characters = $c->stash->{party}->characters;

    my ( $cost_to_heal, @dead_chars ) = _get_party_health( $town, @characters );

    my $amount_to_spend = defined $c->req->param('gold') ? $c->req->param('gold') : $cost_to_heal;

    my $percent_to_heal = $amount_to_spend / $cost_to_heal * 100;

    if ( $amount_to_spend <= $c->stash->{party}->gold ) {
        $c->stash->{party}->gold( $c->stash->{party}->gold - $amount_to_spend );
        $c->stash->{party}->update;

        foreach my $character (@characters) {
            next if $character->is_dead;

            my $amount_to_heal = int( $character->max_hit_points - $character->hit_points ) * ( $percent_to_heal / 100 );

            $character->hit_points( $character->hit_points + $amount_to_heal );
            $character->update;
        }

        if ( $percent_to_heal == 100 ) {
            $c->stash->{messages} = 'The party has been fully healed';
        }
        else {
            $c->stash->{messages} = "The party has been healed for $amount_to_spend gold";
        }
    }
    else {
        if ( $c->req->param('gold') ) {
            $c->stash->{error} = "You only have " . $c->stash->{party}->gold . " gold. You can't heal for more gold than you have!";
        }
        else {
            $c->stash->{error} = "You don't have enough gold for a full heal. Try a partial heal";
        }
    }

    push @{ $c->stash->{refresh_panels} }, ( 'party', 'party_status' );

    $c->forward('/town/healer');
}

sub resurrect : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @characters = $c->stash->{party}->characters;

    my ( $cost_to_heal, @dead_chars ) = _get_party_health( $town, @characters );

    my ($char_to_res) = grep { $_->id eq $c->req->param('character_id') } @dead_chars;

    if ($char_to_res) {
        if ( $char_to_res->resurrect_cost > $c->stash->{party}->gold ) {
            $c->stash->{error} = "You don't have enough gold to resurrect " . $char_to_res->character_name;
        }
        else {
            $c->stash->{party}->gold( $c->stash->{party}->gold - $char_to_res->resurrect_cost );
            $c->stash->{party}->update;

            $char_to_res->hit_points( round $char_to_res->max_hit_points * 0.1 );
            $char_to_res->hit_points(1) if $char_to_res->hit_points < 1;
            my $xp_to_lose = int( $char_to_res->xp * RPG->config->{ressurection_percent_xp_to_lose} / 100 );
            $char_to_res->xp( $char_to_res->xp - $xp_to_lose );
            $char_to_res->update;

            my $message =
                  $char_to_res->character_name
                . " was ressurected by the healer in the town of "
                . $town->town_name
                . " and has risen from the dead. "
                . $char_to_res->pronoun('subjective')
                . " lost $xp_to_lose xp.";

            $c->model('DBIC::Character_History')->create(
                {
                    character_id => $char_to_res->id,
                    day_id       => $c->stash->{today}->id,
                    event        => $message,
                },
            );

            $c->stash->{messages} = $message;
        }
    }

    push @{ $c->stash->{refresh_panels} }, ( 'party', 'party_status' );

    $c->forward('/town/healer');
}

sub _get_party_health {
    my ( $town, @characters ) = @_;

    my $per_hp_heal_cost = round( RPG->config->{min_healer_cost} + ( 100 - $town->prosperity ) / 100 * RPG->config->{max_healer_cost} );
    my $cost_to_heal = 0;
    my @dead_chars;

    foreach my $character (@characters) {
        if ( $character->is_dead ) {
            push @dead_chars, $character;
            next;
        }

        $cost_to_heal += $per_hp_heal_cost * ( $character->max_hit_points - $character->hit_points );
    }

    return ( $cost_to_heal, @dead_chars );
}

sub news : Local {
    my ( $self, $c ) = @_;

    my $current_day = $c->stash->{today}->day_number;

    my @logs = $c->model('DBIC::Combat_Log')->get_logs_around_sector(
        $c->stash->{party_location}->x,
        $c->stash->{party_location}->y,
        $c->config->{combat_news_x_size},
        $c->config->{combat_news_y_size},
        $current_day - $c->config->{combat_news_day_range},
    );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/news.html',
                params   => {
                    town        => $c->stash->{party_location}->town,
                    combat_logs => \@logs,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub town_hall : Local {
    my ( $self, $c ) = @_;

    # See if party has a quest for this town
    my $party_quest = $c->model('DBIC::Quest')->find(
        {
            town_id  => $c->stash->{party_location}->town->id,
            party_id => $c->stash->{party}->id,
            status   => 'In Progress',
        },
    );

    # If the have a quest to complete, send them there now
    if ( $party_quest && $party_quest->ready_to_complete ) {
        $c->detach( '/quest/complete_quest', [$party_quest] );
    }

    # Check for quest actions which can be triggered by a visit to the town hall
    my $quest_messages = $c->forward( '/quest/check_action', ['townhall_visit'] );

    my $party_quests_rs = $c->model('DBIC::Quest')->search(
        {
            party_id => $c->stash->{party}->id,
            status   => 'In Progress',
        },
    );

    my $number_of_quests_allowed = $c->config->{base_allowed_quests} + ( $c->config->{additional_quests_per_level} * $c->stash->{party}->level );
    my $allowed_more_quests = 1;
    if ( $party_quests_rs->count >= $number_of_quests_allowed ) {
        $allowed_more_quests = 0;
    }

    my @quests;

    # If they don't have a quest, load in available quests
    if ( !$party_quest && $allowed_more_quests ) {
        @quests = shuffle $c->model('DBIC::Quest')->search(
            {
                town_id        => $c->stash->{party_location}->town->id,
                party_id       => undef,
                'me.min_level' => { '<=', $c->stash->{party}->level },
            },
            { prefetch => 'type', },
        );
    }

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/town_hall.html',
                params   => {
                    town                => $c->stash->{party_location}->town,
                    quests              => \@quests,
                    party_quest         => $party_quest,
                    allowed_more_quests => $allowed_more_quests,
                    quest_messages      => $quest_messages,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub sage : Local {
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

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/sage.html',
                params   => {
                    direction_cost                   => $c->config->{sage_direction_cost},
                    distance_cost                    => $c->config->{sage_distance_cost},
                    location_cost                    => $c->config->{sage_location_cost},
                    item_types                       => \@item_types,
                    item_find_cost                   => $c->config->{sage_item_find_cost},
                    dungeon_levels_allowed_to_enter  => \@dungeon_levels_allowed_to_enter,
                    sage_find_dungeon_cost_per_level => $c->config->{sage_find_dungeon_cost_per_level},
                    town                             => $c->stash->{party_location}->town,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages',       $panel ];
    push @{ $c->stash->{refresh_panels} }, [ 'popup-messages', $c->stash->{messages} ];

    $c->forward('/panel/refresh');
}

sub find_town : Local {
    my ( $self, $c ) = @_;

    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};

    unless ( $party_location->town ) {
        $c->error("Not in a town!");
        return;
    }

    my $message;
    my $error;

    eval {
        my $cost = $c->config->{ 'sage_' . $c->req->param('find_type') . '_cost' };

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

    $c->forward('/town/sage');
}

sub find_item : Local {
    my ( $self, $c ) = @_;

    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};

    unless ( $party_location->town ) {
        $c->error("Not in a town!");
        return;
    }

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

                $party->gold( $party->gold - $c->config->{sage_item_find_cost} );
                $party->update;
            }
        }
    }

    $c->stash->{messages} = $message;

    push @{ $c->stash->{refresh_panels} }, ('party_status');

    $c->forward('/town/sage');
}

sub find_dungeon : Local {
    my ( $self, $c ) = @_;

    my $party          = $c->stash->{party};
    my $party_location = $c->stash->{party_location};

    unless ( $party_location->town ) {
        $c->error("Not in a town!");
        return;
    }

    my $message = eval {
        my $level = $c->req->param('find_level') || croak "Level not defined";

        unless ( RPG::Schema::Dungeon->party_can_enter( $level, $party ) ) {
            return "You're not high enough level to find a dungeon of that level";
        }

        my $cost = $c->config->{sage_find_dungeon_cost_per_level} * $level;

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
                party_id => $party->id,
                land_id  => $dungeon->land_id,
            );

            unless ($mapped_sector) {
                $dungeon_to_find = $dungeon;
                last;
            }
        }

        unless ($dungeon_to_find) {
            return "Sorry, you already know about all the nearby dungeons of that level";
        }

        # Add to mapped sectors
        $c->model('DBIC::Mapped_Sectors')->create(
            {
                land_id  => $dungeon_to_find->land_id,
                party_id => $party->id,
            }
        );

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

    $c->forward('/town/sage');
}

sub cemetry : Local {
    my ( $self, $c ) = @_;

    my @graves = $c->model('DBIC::Grave')->search( { land_id => $c->stash->{party_location}->id, }, );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'town/cemetery.html',
                params        => { graves => \@graves, },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub enter : Local {
    my ( $self, $c ) = @_;

    my $town = $c->model('DBIC::Town')->find( { land_id => $c->req->param('land_id') } );
    my $cost = $town->tax_cost( $c->stash->{party} );

    if ( $c->req->param('payment_method') eq 'gold' ) {
        if ( $cost->{gold} > $c->stash->{party}->gold ) {
            $c->stash->{error} = "You don't have enough gold to pay the tax";
            $c->detach('/panel/refresh');
        }

        $c->stash->{party}->gold( $c->stash->{party}->gold - $cost->{gold} );
    }
    else {
        if ( $cost->{turns} > $c->stash->{party}->turns ) {
            $c->stash->{error} = "You don't have enough turns to pay the tax";
            $c->detach('/panel/refresh');
        }

        $c->stash->{party}->turns( $c->stash->{party}->turns - $cost->{turns} );
    }

    # Record payment
    my $party_town = $c->model('Party_Town')->update_or_create(
        {
            party_id              => $c->stash->{party}->id,
            town_id               => $town->id,
            tax_amount_paid_today => $cost->{gold},            # Always recorded in gold
        },
    );

    $c->forward('/map/move_to');
}

sub raid : Local {
    my ( $self, $c ) = @_;

    croak "Not high enough level for that" unless $c->stash->{party}->level >= $c->config->{minimum_raid_level};

    my $town = $c->model('DBIC::Town')->find( { town_id => $c->req->param('town_id') } );

    croak "Invalid town id" unless $town;

    croak "Not next to that town" unless $c->stash->{party_location}->next_to( $town->location );

    my $turn_cost = round $town->prosperity / 4;

    if ( $turn_cost > $c->stash->{party}->turns ) {
        $c->stash->{error} = "You need at least $turn_cost turns to raid this town";
        $c->detach('/panel/refresh');
    }

    my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
        {
            town_id  => $town->id,
            party_id => $c->stash->{party}->id,
        }
    );

    my $party_raid_factor =
        ( $c->stash->{party}->average_stat('intelligence') / 2 ) +
        $c->stash->{party}->average_stat('agility') +
        ( $c->stash->{party}->average_stat('divinity') / 2 );

    my $town_raid_factor = $town->prosperity + (($town->prosperity / 4) * ($party_town->raids_today || 0)); 

    my $raid_factor = round $town_raid_factor - round $party_raid_factor;
    my $raid_roll   = Games::Dice::Advanced->roll('1d100');

    my $raid_quotient = $raid_factor - $raid_roll;

    my $base_gold    = $town->prosperity * 6;
    my $gold_to_gain = $base_gold + Games::Dice::Advanced->roll( '1d' . $base_gold );

    $c->log->debug( "Town Prosp: "
            . $town->prosperity
            . " Town Raid Factor: $town_raid_factor, Party Raid Factor: $party_raid_factor, Raid Factor: $raid_factor, Raid Roll: $raid_roll, "
            . "Raid Qiotient: $raid_quotient, Gold To Gain: $gold_to_gain" );

    my $raid_successful = 0;

    given ($raid_quotient) {
        when ( $_ < -60 ) {

            # Success, no consequence
            $c->stash->{party}->gold( $c->stash->{party}->gold + $gold_to_gain );
            $c->stash->{messages} =
                ["You charge past the guards without anyone ever noticing you. You steal $gold_to_gain gold from the treasury"];
            $raid_successful = 1;
        }
        when ( $_ < -40 ) {

            # Success, but prestige reduced
            $c->stash->{party}->gold( $c->stash->{party}->gold + $gold_to_gain );
            $c->stash->{messages} =
                [     "You make it to the treasury and steal $gold_to_gain gold. On the way out, a guard spots you, and gives chase. You get "
                    . "away, but this will surely affect your prestige with the town." ];
            $raid_successful = 1;                    
        }
        when ( $_ < -20 ) {

            # Failure, prestige reduced
            $c->stash->{messages} =
                [     "You get halfway to the treasury only to run into a squard of guards. You turn on your heels, and run your hearts out, making "
                    . " it out of the gates before the guards can catch you. It's not too likely they'll want to see you back there any time soon" ];
        }
        default {

            # Failure and imprisonment
            my $turns_lost = round $town->prosperity / 4;
            $turns_lost = 2 if $turns_lost < 2;

            $c->stash->{messages} =
                [     "You're just loading up on sacks of gold when the guards burst through the door. You've been caught red-handed! "
                    . "You're imprisoned for $turns_lost turns" ];

            $c->stash->{party}->turns( $c->stash->{party}->turns - $turns_lost );
        }
    }
    
    if ($raid_successful) {
        my $quest_messages = $c->forward( '/quest/check_action', ['town_raid', $town->id] );
        
        if ($quest_messages) {
            push @{ $c->stash->{messages} }, @$quest_messages;
        }
    }

    $c->stash->{party}->turns( $c->stash->{party}->turns - $turn_cost );
    $c->stash->{party}->update;
    
    $party_town->raids_today(($party_town->raids_today||0)+1);
    $party_town->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

1;
