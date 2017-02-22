package RPG::C::Building;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use Data::Dumper;

use List::Util qw(shuffle);

sub auto : Private {
    my ( $self, $c ) = @_;

    if ( $c->stash->{party}->in_combat ) {
        croak "Can't manage buildings while in combat";
    }

    $c->stash->{location} = $c->stash->{town} ? $c->stash->{town}->location : $c->stash->{party_location};

    $c->stash->{building} = $c->stash->{location}->building;

    return 1;
}

sub get_valid_groups {
    my ( $self, $c ) = @_;

    my @groups;

    if ( $c->stash->{town} ) {
        my $mayor_cg = $c->stash->{town}->mayor->creature_group;
        push @groups, $mayor_cg if $mayor_cg;

        if ( $c->stash->{party}->land_id == $c->stash->{town}->land_id ) {
            push @groups, $c->stash->{party};
        }
    }
    else {
        @groups = ( $c->stash->{party} );

        my $garrison;
        if ( $garrison = $c->stash->{party}->location->garrison and $garrison->party_id == $c->stash->{party}->id ) {
            push @groups, $garrison;
        }
    }

    return @groups;

}

sub get_party_resources {
    my ( $self, $c ) = @_;

    #  Get the list of resources owned by the current party.
    my %resources;

    my @equipment;
    my @groups = $self->get_valid_groups( $c, $c->stash->{town} );

    foreach my $group (@groups) {
        next unless $group;
        push @equipment, $group->get_equipment('Resource');
    }

    foreach my $resource (@equipment) {
        $resources{ $resource->item_type->item_type } += $resource->variable('Quantity') // 0;
    }

    return %resources;
}

sub construct : Local {
    my ( $self, $c ) = @_;

    my $building_type = $c->model('DBIC::Building_Type')->find(
        {
            level => 1,
        }
    );

    my %party_resources = $self->get_party_resources( $c, $c->stash->{town} );

    my %resources = map { $_->item_type => $_ } $c->model('DBIC::Item_Type')->search(
        {
            'category.item_category' => 'Resource',
        },
        {
            join => 'category',
        }
    );

    my @groups = $self->get_valid_groups( $c, $c->stash->{town} );

    my %resources_needed = $building_type->cost_to_build( \@groups );
    my $enough_resources = $building_type->enough_resources( \@groups, %party_resources );

    $c->forward( 'RPG::V::TT',
        [ {
                template => 'building/construct.html',
                params   => {
                    party            => $c->stash->{party},
                    building_type    => $building_type,
                    party_resources  => \%party_resources,
                    enough_resources => $enough_resources,
                    resources        => \%resources,
                    resources_needed => \%resources_needed,
                    town             => $c->stash->{town},
                },
            } ]
    );
}

sub build : Local {
    my ( $self, $c ) = @_;

    if ( $c->stash->{building} ) {
        $c->stash->{error} = "There's already a building in this sector!";
        $c->detach('/panel/refresh');
    }

    my $town = $c->stash->{town};

    my $building_type = $c->model('DBIC::Building_Type')->find(
        {
            level => 1,
        }
    );

    my @groups = $self->get_valid_groups( $c, $town );

    if ( !$building_type->enough_turns( $c->stash->{party} ) ) {
        $c->stash->{error} = $c->forward( '/party/not_enough_turns', ['construct the building'] );
        $c->detach('/panel/refresh');
    }

    my %resources_needed = $building_type->cost_to_build( \@groups );

    if ( !$building_type->consume_items( \@groups, %resources_needed ) ) {
        $c->stash->{error} = "Your party does not have the resources needed to create this building";
        $c->detach('/panel/refresh');
    }

    #  Create the building.
    my $building = $c->model('DBIC::Building')->create(
        {
            land_id          => $c->stash->{location}->land_id,
            building_type_id => $building_type->id,
            owner_id         => $town ? $town->id : $c->stash->{party}->id,
            owner_type       => $town ? 'town' : 'party',
            name             => $building_type->name,

            #  For now, partial construction not allowed, so we use all the materials up front
            'clay_needed'  => 0,
            'stone_needed' => 0,
            'wood_needed'  => 0,
            'iron_needed'  => 0,
            'labor_needed' => 0,
        }
    );

    $c->stash->{party}->turns( $c->stash->{party}->turns - $building_type->turns_needed( $c->stash->{party} ) );
    $c->stash->{party}->update;

    if ( !$town ) {
        $c->forward( 'change_building_ownership', [$building] );

        $c->model('DBIC::Party_Messages')->create(
            {
                message => "We created a " . $building_type->name . " at " . $c->stash->{party}->location->x . ", "
                  . $c->stash->{party}->location->y,
                alert_party => 0,
                party_id    => $c->stash->{party}->id,
                day_id      => $c->stash->{today}->id,
            }
        );

        my $message = $c->forward( '/quest/check_action', [ 'constructed_building', $building ] );

        push @$message, "Building created";

        $c->stash->{panel_messages} = $message if @$message;

        $c->forward('/map/refresh_current_loc');

        $c->forward( '/panel/refresh', [ [ screen => 'close' ], 'party_status', 'messages' ] );
    }
}

sub manage : Local {
    my ( $self, $c ) = @_;

    my $building = $c->stash->{building};

    croak "No buildings to upgrade\n" unless $building;

    croak "Not allowed to manage building" unless $building->allowed_to_manage( $c->stash->{party} );

    my $town = $c->stash->{town};

    my $building_type = $building->building_type;

    my @groups = $self->get_valid_groups( $c, $town );

    my $upgradable_to_type = $c->model('DBIC::Building_Type')->find(
        {
            level => $building_type->level + 1,
        }
    );

    my @upgrade_types = $c->model('DBIC::Building_Upgrade_Type')->search();

    my %upgrades_by_type_id = map { $_->type_id => $_ } $building->upgrades;

    my %party_resources = $self->get_party_resources( $c, $town );

    my %resources = map { $_->item_type => $_ } $c->model('DBIC::Item_Type')->search(
        {
            'category.item_category' => 'Resource',
        },
        {
            join => 'category',
        }
    );

    my %resources_needed;
    my $enough_resources = 0;

    if ($upgradable_to_type) {
        %resources_needed = $upgradable_to_type->cost_to_build( \@groups );
        $enough_resources = $upgradable_to_type ? $upgradable_to_type->enough_resources( \@groups, %party_resources ) : 1;
    }

    $c->forward( 'RPG::V::TT',
        [ {
                template => 'building/manage.html',
                params   => {
                    party               => $c->stash->{party},
                    building_type       => $building_type,
                    upgradable_to_type  => $upgradable_to_type,
                    party_resources     => \%party_resources,
                    enough_resources    => $enough_resources,
                    resources           => \%resources,
                    resources_needed    => \%resources_needed,
                    town                => $town,
                    upgrade_types       => \@upgrade_types,
                    upgrades_by_type_id => \%upgrades_by_type_id,
                    building_url_prefix => $c->stash->{building_url_prefix},
                    building_owner_type => $building->owner_type,
                },
            } ]
    );
}

sub upgrade : Local {
    my ( $self, $c ) = @_;

    my $building = $c->stash->{building};

    croak "No buildings to upgrade\n" unless $building;

    croak "Not allowed to manage building" unless $building->allowed_to_manage( $c->stash->{party} );

    my $town = $c->stash->{town};

    my $building_type = $building->building_type;

    my $upgradable_to_type = $c->model('DBIC::Building_Type')->find(
        {
            level => $building_type->level + 1,
        }
    );

    croak "Building can't be upgraded\n" unless $upgradable_to_type;

    if ( !$town && !$upgradable_to_type->enough_turns( $c->stash->{party} ) ) {
        $c->stash->{error} = $c->forward( '/party/not_enough_turns', ['upgrade the building'] );
        $c->detach('/panel/refresh');
    }

    my @groups = $self->get_valid_groups( $c, $town );

    my %resources_needed = $upgradable_to_type->cost_to_build( \@groups );

    if ( !$building_type->consume_items( \@groups, %resources_needed ) ) {
        $c->stash->{error} = "Your party does not have the resources needed to upgrade this building";
        $c->detach('/panel/refresh');
    }

    $building->building_type_id( $upgradable_to_type->id );
    $building->update;

    if ( !$c->stash->{no_refresh} ) {
        $c->forward( 'change_building_ownership', [$building] );

        $c->stash->{party}->turns( $c->stash->{party}->turns - $building_type->turns_needed( $c->stash->{party} ) );
        $c->stash->{party}->update;

        $c->stash->{panel_messages} = ["Building upgraded"];

        $c->forward('/map/refresh_current_loc');

        $c->forward( '/panel/refresh', [ [ screen => 'close' ], 'party_status', 'messages' ] );
    }
}

sub build_upgrade : Local {
    my ( $self, $c ) = @_;

    my $building = $c->stash->{building};

    croak "Not allowed to manage building" unless $building->allowed_to_manage( $c->stash->{party} );

    my $town = $c->stash->{town};

    my $upgrade = $c->model('DBIC::Building_Upgrade')->find_or_create(
        {
            'building_id' => $building->id,
            'type_id'     => $c->req->param('upgrade_type_id'),
        },
        {
            for      => 'update',
            prefetch => 'type',
        },
    );

    if ( $building->building_type->max_upgrade_level < $upgrade->level + 1 ) {
        croak "Cannot upgrade pasts max base building upgrade level";
    }

    my %resources_needed = %{ $upgrade->type->cost_to_upgrade( $upgrade->level + 1 ) };

    my $turns_needed = delete $resources_needed{Turns};
    my $gold_needed  = delete $resources_needed{Gold};

    my @groups = $self->get_valid_groups( $c, $town );

    if ( !$upgrade->type->consume_items( \@groups, %resources_needed ) ) {
        $c->stash->{error} = "Your party does not have the resources needed to build this upgrade";
        $c->detach('/panel/refresh');
    }

    if ( $turns_needed > $c->stash->{party}->turns || $gold_needed > $c->stash->{party}->gold ) {
        croak "Not enough turns or gold to build upgrade";
    }

    $c->stash->{party}->decrease_gold($gold_needed);
    $c->stash->{party}->turns( $c->stash->{party}->turns - $turns_needed );
    $c->stash->{party}->update;

    $upgrade->level( $upgrade->level + 1 );
    $upgrade->update;

    if ( !$c->stash->{no_refresh} ) {
        $c->forward( '/panel/refresh', [ [ screen => 'building/manage' ], 'party_status' ] );
    }

}

sub seize : Local {
    my ( $self, $c ) = @_;

    #  Check party level.
    if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
        croak "You can't seize building - your party level is too low";
    }

    if ( $c->stash->{party_location}->garrison && $c->stash->{party_location}->garrison->party_id != $c->stash->{party}->id ) {
        croak "Can't seize a building with a garrison";
    }

    if ( $c->stash->{party}->turns < $c->config->{building_seize_turn_cost} ) {
        $c->stash->{error} = "You need at least " . $c->config->{building_seize_turn_cost} . " turns to seize the building";
        $c->detach('/panel/refresh');
    }

    my $building = $c->stash->{building};

    croak "Cannot seize a town's building" if $building->owner_type eq 'town';

    croak "No building to seize\n" unless $building;

    # Make sure this building is indeed owned by another party.
    if ( $c->stash->{party}->id == $building->owner_id && $building->owner_type eq 'party' ) {
        croak "You cannot seize your own building\n";
    }

    $c->forward( 'change_building_ownership', [$building] );

    #  Give the former owner the unfortunate news.
    my $message = "Our building at " . $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y .
      " was seized from us by " . $c->stash->{party}->name;

    if ( $building->owner_type eq 'party' ) {
        $c->model('DBIC::Party_Messages')->create(
            {
                message     => $message,
                alert_party => 1,
                party_id    => $building->owner_id,
                day_id      => $c->stash->{today}->id,
            }
        );
    }
    elsif ( $building->owner_type eq 'kingdom' ) {
        $c->model('DBIC::Kingdom_Messages')->create(
            {
                kingdom_id => $building->owner_id,
                day_id     => $c->stash->{today}->id,
                message    => $message,
            }
        );

        # If they party seized a building belonging to their kingdom, reduce loyalty
        if ( $building->owner_id == $c->stash->{party}->kingdom_id ) {
            my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
                {
                    kingdom_id => $c->stash->{party}->kingdom_id,
                    party_id   => $c->stash->{party}->id,
                }
            );

            $party_kingdom->decrease_loyalty(7);
            $party_kingdom->update;
        }

    }

    #  But crow about it to ourselves.
    $c->model('DBIC::Party_Messages')->create(
        {
            message => "We seized the " . $building->name . " at " . $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y,
            alert_party => 0,
            party_id    => $c->stash->{party}->id,
            day_id      => $c->stash->{today}->id,
        }
    );

    #  Update the ownership building
    $building->owner_id( $c->stash->{party}->id );
    $building->owner_type('party');
    $building->update;

    $c->stash->{party}->turns( $c->stash->{party}->turns - $c->config->{building_seize_turn_cost} );
    $c->stash->{party}->update;

    $c->stash->{panel_messages} = ['Building Seized'];

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] ) unless $c->stash->{no_refresh};
}

sub raze : Local {
    my ( $self, $c ) = @_;

    #  Check party level.
    if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
        croak "You can't raze building - your party level is too low";
    }

    my $building = $c->stash->{building};

    croak "No building to raze\n" unless $building;

    croak "Cannot raze a town's building" if $building->owner_type eq 'town';

    my $turns_to_raze = $building->building_type->turns_to_raze( $c->stash->{party} );

    if ( !$c->req->param('raze_confirmed') ) {
        $c->forward( '/panel/create_submit_dialog_from_template',
            [
                {
                    template => 'building/confirm_raze.html',
                    params   => {
                        turns_to_raze => $turns_to_raze,
                    },
                    submit_url   => '/building/raze',
                    dialog_title => 'Confirm Raze',
                }
            ],
        );
        $c->detach('/panel/refresh');
    }

    #  Make sure the party has enough turns to raze.
    if ( $c->stash->{party}->turns < $turns_to_raze ) {
        $c->stash->{error} = "You need at least " . $turns_to_raze . " turns to raze the building";
        $c->detach('/panel/refresh');
    }

    if ( $c->stash->{party_location}->garrison && $c->stash->{party_location}->garrison->party_id != $c->stash->{party}->id ) {
        croak "Can't raze a building with a garrison";
    }

    #  If we don't own this building, give the former owner the bad news.
    my $message = "Our building at " .
      $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y .
      " was razed by " . $c->stash->{party}->name;
    if ( $c->stash->{party}->id != $building->owner_id && $building->owner_type eq 'party' ) {
        $c->model('DBIC::Party_Messages')->create(
            {
                message     => $message,
                alert_party => 1,
                party_id    => $building->owner_id,
                day_id      => $c->stash->{today}->id,
            }
        );
    }
    elsif ( $building->owner_type eq 'kingdom' ) {
        $c->model('DBIC::Kingdom_Messages')->create(
            {
                message    => $message,
                kingdom_id => $building->owner_id,
                day_id     => $c->stash->{today}->id,
            }
        );

        # If the party razed a building belonging to their kingdom, reduce loyalty
        if ( $building->owner_id == $c->stash->{party}->kingdom_id ) {
            my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
                {
                    kingdom_id => $c->stash->{party}->kingdom_id,
                    party_id   => $c->stash->{party}->id,
                }
            );

            $party_kingdom->decrease_loyalty(10);
            $party_kingdom->update;
        }

    }

    $c->model('DBIC::Party_Messages')->create(
        {
            message => "We razed the " . $building->name . " at " . $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y,
            alert_party => 0,
            party_id    => $c->stash->{party}->id,
            day_id      => $c->stash->{today}->id,
        }
    );

    $building->unclaim_land;
    $building->delete;

    $c->stash->{panel_messages} = ['Building Razed!'];

    $c->stash->{party}->turns( $c->stash->{party}->turns - $turns_to_raze );
    $c->stash->{party}->update;

    $c->forward('/map/refresh_current_loc');

    $c->forward( '/panel/refresh', [ [ screen => 'close' ], 'messages', 'party_status' ] ) unless $c->stash->{no_refresh};
}

sub cede : Local {
    my ( $self, $c ) = @_;

    croak "You don't have a Kingdom" unless $c->stash->{party}->kingdom_id;

    my $building = $c->stash->{building};

    croak "No building to cede\n" unless $building;

    if ( $building->owner_type ne 'party' or $building->owner_id != $c->stash->{party}->id ) {
        croak "Not owner of the building\n";
    }

    my @messages;

    $building->owner_type('kingdom');
    $building->owner_id( $c->stash->{party}->kingdom_id );
    $building->update;

    # If there's a garrison in this sector, and they're claiming land for the kingdom,
    #  cancel this, as the building will now claim the land.
    my $garrison = $building->location->garrison;
    if ( $garrison->claim_land_order ) {
        $garrison->unclaim_land;
    }

    $c->forward( 'change_building_ownership', [$building] );

    my $message = $c->forward( '/quest/check_action', [ 'ceded_building', $building ] );
    push @messages, @$message if @$message;

    $c->stash->{party}->kingdom->add_to_messages(
        {
            day_id => $c->stash->{today}->id,
            message => "The party " . $c->stash->{party}->name . " ceded a building to the kingdom at "
              . $c->stash->{party_location}->x . ', ' . $c->stash->{party_location}->y,
        }
    );

    # Increase loyalty
    my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
        {
            kingdom_id => $c->stash->{party}->kingdom_id,
            party_id   => $c->stash->{party}->id,
        }
    );

    $party_kingdom->increase_loyalty(7);
    $party_kingdom->update;

    push @messages, 'Building ceded to the Kingdom of ' . $c->stash->{party}->kingdom->name;
    $c->stash->{panel_messages} = \@messages;

    $c->forward( '/panel/refresh', [ [ screen => 'close' ], 'messages' ] );

}

sub change_building_ownership : Private {
    my ( $self, $c, $building ) = @_;

    $building->unclaim_land;
    $building->claim_land;
}

1;
