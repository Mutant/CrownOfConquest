package RPG::C::Town::Blacksmith;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

use Games::Dice::Advanced;

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward('main');
}

sub main : Local {
    my ( $self, $c ) = @_;

    my @categories = $c->model('DBIC::Item_Category')->search(
        { 'property_category.category_name' => [ 'Upgrade', 'Durability' ], },
        {
            join => { 'item_variable_names' => 'property_category' },
            distinct => 1,
            order_by => 'item_category',
        }
    );
    my @items = $c->model('DBIC::Items')->party_items_requiring_repair( $c->stash->{party}->id, );

    my ( $full_repair_cost, $equipped_repair_cost );
    foreach my $item (@items) {
        my $repair_cost = $item->repair_cost( $c->stash->{party_location}->town );

        $full_repair_cost += $repair_cost;
        $equipped_repair_cost += $repair_cost if $item->equip_place_id;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/blacksmith.html',
                params   => {
                    town                 => $c->stash->{party_location}->town,
                    party                => $c->stash->{party},
                    current_tab          => $c->flash->{current_tab},
                    gold                 => $c->stash->{party}->gold,
                    full_repair_cost     => $full_repair_cost,
                    equipped_repair_cost => $equipped_repair_cost,
                    categories           => \@categories,
                },
                return_output => 0,
            }
        ]
    );

}

sub category_tab : Local {
    my ( $self, $c ) = @_;

    my $category =
      $c->model('DBIC::Item_Category')->find( { 'item_category_id' => $c->req->param('category_id'), }, { prefetch => 'item_variable_names', } );

    my @upgrade_variables = $category->variables_in_property_category( 'Upgrade', 1 );
    my @repair_variables = $category->variables_in_property_category( 'Durability', 1 );

    my @items = $c->model('DBIC::Items')->party_items_in_category( $c->stash->{party}->id, $c->req->param('category_id') );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/blacksmith/category_tab.html',
                params   => {
                    items             => \@items,
                    upgrade_variables => \@upgrade_variables,
                    repair_variables  => \@repair_variables,
                    town              => $c->stash->{party_location}->town,
                    category          => $category,
                },
                return_output => 0,
            }
        ]
    );
}

sub item_valid_check : Private {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    if ( $town->blacksmith_age == 0 ) {
        croak "No blacksmith in this town\n";
    }

    my %extra_params = map { 'belongs_to_character.' . $_ => undef } RPG::Schema::Character->in_party_columns;
    my $item = $c->model('DBIC::Items')->find(
        {
            item_id  => $c->req->param('item_id'),
            party_id => $c->stash->{party}->id,
            %extra_params,
        },
        {
            prefetch => [ 'belongs_to_character', 'item_type' ]
        }
    );

    unless ($item) {
        croak "Attempting to upgrade weapon for a character not in the party\n";
    }

    return $item;
}

sub upgrade : Local {
    my ( $self, $c ) = @_;

    $c->flash->{current_tab} = $c->req->param('current_tab');

    my $item = $c->forward('item_valid_check');

    if ( !$item->variable('Indestructible') && $item->variable('Durability') < $c->config->{min_upgrade_durability} ) {
        $c->stash->{error} = "The item is too fragile to upgrade";
        $c->forward('/panel/refresh');
        return;
    }

    my $town = $c->stash->{party_location}->town;

    my $variable = $c->model('DBIC::Item_Variable_Name')->find(
        {
            'item_variable_name_id' => $c->req->param('variable_id'),
            'item_category_id'      => $item->item_type->item_category_id,
            'property_category.category_name' => 'Upgrade',
        },
        { join => 'property_category' }
    );

    if ( !$variable ) {
        croak "Item variable doesn't exist for this item type\n";
    }

    if ( $item->upgrade_cost( $variable->item_variable_name ) > $c->stash->{party}->gold ) {
        $c->log->debug("Not enough gold for upgrade");
        $c->stash->{error} = "You don't have enough gold for that upgrade";
        $c->forward('/panel/refresh');
        return;
    }

    $c->stash->{party}->gold( $c->stash->{party}->gold - $item->upgrade_cost( $variable->item_variable_name ) );
    $c->stash->{party}->update;

    my $item_variable = $item->variable_row( $variable->item_variable_name );
    if ( !$item_variable ) {
        $item_variable = $c->model('DBIC::Item_Variable')->create(
            {
                item_id               => $item->id,
                item_variable_name_id => $variable->id,
                item_variable_value   => 0,
            }
        );
    }

    my $upgrade_increase = $town->blacksmith_skill - $item_variable->item_variable_value;
    $upgrade_increase = 0 if $upgrade_increase < 0;
    $upgrade_increase = 5 if $upgrade_increase > 5;

    my $random_factor = Games::Dice::Advanced->roll('1d100');

    for ($random_factor) {
        if ( $_ <= 10 ) {
            $upgrade_increase -= 2;
        }
        elsif ( $_ <= 30 ) {
            $upgrade_increase--;
        }
        elsif ( $_ >= 70 ) {
            $upgrade_increase++;
        }
        elsif ( $_ >= 90 ) {
            $upgrade_increase += 2;
        }
    }

    $upgrade_increase = 0 if $upgrade_increase < 0;
    $upgrade_increase = 5 if $upgrade_increase > 5;

    $item_variable->item_variable_value( $item_variable->item_variable_value + $upgrade_increase );
    $item_variable->update;

    # Reduce Durability
    my $durability_decrease = 0;
    if ( $upgrade_increase > 0 ) {
        $durability_decrease = Games::Dice::Advanced->roll('1d20') - int( $town->blacksmith_skill / 3 );
        $durability_decrease = 0 if $durability_decrease < 0;

        if ( my $durabilty_variable = $item->variable_row('Durability') ) {
            $durabilty_variable->max_value( $durabilty_variable->max_value - $durability_decrease );
            $durabilty_variable->item_variable_value( $durabilty_variable->max_value )
              if $durabilty_variable->item_variable_value > $durabilty_variable->max_value;
            $durabilty_variable->update;
        }
        else {
            $durability_decrease = 0;
        }
    }

    my $character = $item->belongs_to_character;
    $character->calculate_attack_factor;
    $character->calculate_defence_factor;
    $character->update;

    # TODO: bit of a hack getting the name of the upgraded attribute with a regex...
    my ($upgraded_attribute) = ( $variable->item_variable_name =~ /(.+) Upgrade$/ );

    $c->stash->{panel_messages} = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/blacksmith/upgrade_message.html',
                params   => {
                    item                => $item,
                    upgrade_increase    => $upgrade_increase,
                    upgraded_attribute  => $upgraded_attribute,
                    durability_decrease => $durability_decrease,
                },
                return_output => 1,
            }
        ]
    );

    $c->forward( '/panel/refresh', [ [ screen => 'town/blacksmith/main' ], 'party_status' ] );

}

sub repair : Local {
    my ( $self, $c ) = @_;

    $c->flash->{current_tab} = $c->req->param('current_tab');

    my $item = $c->forward('item_valid_check');

    my $town = $c->stash->{party_location}->town;

    if ( $item->repair_cost($town) == 0 ) {

        # No repair needed
        return;
    }

    if ( $item->repair_cost($town) > $c->stash->{party}->gold ) {
        $c->stash->{error} = "You don't have enough gold for that repair";
        $c->forward('/panel/refresh');
        return;
    }

    $c->stash->{party}->gold( $c->stash->{party}->gold - $item->repair_cost($town) );
    $c->stash->{party}->update;

    $item->repair;

    $c->stash->{message} = "Repair complete";
    $c->forward( '/panel/refresh', [ [ screen => 'town/blacksmith/main' ], 'party_status', 'party' ] );
}

sub full_repair : Local {
    my ( $self, $c ) = @_;

    my $town  = $c->stash->{party_location}->town;
    my $party = $c->stash->{party};

    if ( $town->blacksmith_age == 0 ) {
        croak "No blacksmith in this town\n";
    }

    my @items = $c->model('DBIC::Items')->party_items_requiring_repair( $party->id, $c->req->param('equipped_only') || 0, );

    my $repaired = 0;
    foreach my $item (@items) {
        if ( $party->gold >= $item->repair_cost($town) ) {
            $repaired++;

            $party->gold( $party->gold - $item->repair_cost($town) );

            $item->repair;
        }
        else {
            last;
        }
    }

    $party->update;

    if ( $repaired == 0 ) {
        $c->stash->{error} = "You don't have enough gold to repair any items";
    }
    elsif ( $repaired < scalar @items ) {
        $c->stash->{error} = "You don't have enough gold to repair all those items. Only the first $repaired items were repaired.";
    }
    else {
        $c->stash->{panel_messages} = "$repaired items repaired";
    }

    $c->forward( '/panel/refresh', [ [ screen => 'town/blacksmith/main' ], 'party_status', 'party' ] );
}

1;
