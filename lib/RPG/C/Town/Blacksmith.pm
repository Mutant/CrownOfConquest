package RPG::C::Town::Blacksmith;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature 'switch';

use Carp;

use Games::Dice::Advanced;

sub default : Path {
    my ( $self, $c ) = @_;
    
    $c->forward('main');
}

sub main : Local {
    my ( $self, $c ) = @_;
    
    my %categories = map { $_->id => $_} $c->model('DBIC::Item_Category')->search(
        {
            'property_category.category_name' => 'Upgrade',
        },
        {
            prefetch => { 'item_variable_names' => 'property_category' },
        }
    );

    my @items = $c->model('DBIC::Items')->search(
        {
            'belongs_to_character.party_id'   => $c->stash->{party}->id,
            'item_type.item_category_id' => [keys %categories],

        },
        {
            prefetch => [ 
                'belongs_to_character', 
                'item_type',
                {'item_variables', => 'item_variable_name'},
            ],
            order_by => 'belongs_to_character.party_order',
            distinct => 1,
        },
    );
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/blacksmith.html',
                params   => {
                    town  => $c->stash->{party_location}->town,
                    items => \@items,
                    error => $c->flash->{error},
                    message => $c->flash->{message},
                    gold => $c->stash->{party}->gold,
                    categories => \%categories,
                },
                return_output => 0,
            }
        ]
    );
}

sub upgrade : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    if ( $town->blacksmith_age == 0 ) {
        croak "No blacksmith in this town\n";
    }

    my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), }, { prefetch => ['belongs_to_character', 'item_type'] } );

    if ( $item->belongs_to_character->party_id != $c->stash->{party}->id ) {
        croak "Attempting to upgrade weapon from different party\n";
    }

    my $variable = $c->model('DBIC::Item_Variable_Name')->find(
        {
            'item_variable_name_id'           => $c->req->param('variable_id'),
            'item_category_id'                => $item->item_type->item_category_id,
            'property_category.category_name' => 'Upgrade',
        },
        { join => 'property_category' }
    );

    if ( !$variable ) {
        croak "Item variable doesn't exist for this item type\n";
    }

    if ( $item->upgrade_cost($variable) > $c->stash->{party}->gold ) {
        $c->log->debug("Not enough gold for upgrade");
        $c->flash->{error} = "You don't have enough gold for that upgrade";
        $c->response->redirect( $c->config->{url_root} . '/town/blacksmith/main' );
        return;
    }
    
    $c->stash->{party}->gold($c->stash->{party}->gold - $item->upgrade_cost($variable));
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

    given ($random_factor) {
        when ( $_ <= 10 ) {
            $upgrade_increase -= 2;
        }
        when ( $_ <= 30 ) {
            $upgrade_increase--;
        }
        when ( $_ >= 70 ) {
            $upgrade_increase++;
        }
        when ( $_ >= 90 ) {
            $upgrade_increase += 2;
        }
    }

    $upgrade_increase = 0 if $upgrade_increase < 0;
    $upgrade_increase = 5 if $upgrade_increase > 5;

    $item_variable->item_variable_value( $item_variable->item_variable_value + $upgrade_increase );
    $item_variable->update;

    # TODO: bit of a hack getting the name of the upgraded attribute with a regex...
    my ($upgraded_attribute) = ( $variable->item_variable_name =~ /(.+) Upgrade$/ );

    $c->flash->{message} = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/blacksmith/upgrade_message.html',
                params   => {
                    item               => $item,
                    upgrade_increase   => $upgrade_increase,
                    upgraded_attribute => $upgraded_attribute,
                },
                return_output => 1,
            }
        ]
    );
    
    $c->response->redirect( $c->config->{url_root} . '/town/blacksmith/main' );

}

1;
