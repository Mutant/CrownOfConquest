use strict;
use warnings;

package RPG::NewDay::Shop;

use Data::Dumper;

use Games::Dice::Advanced;
use Params::Validate qw(:types validate);
use List::Util qw(shuffle);

my ( $config, $schema, $logger );

sub run {
    my $package = shift;
    $config = shift;
    $schema = shift;
    $logger = shift;

    my $town_rs = $schema->resultset('Town')->search( {}, { prefetch => 'shops' } );

    # Get list of item types, as we only need to get it once
    my @item_types = $schema->resultset('Item_Type')->search(
        {
            'category.hidden'           => 0,
            'category.auto_add_to_shop' => 1,
        },
        {
            prefetch => { 'item_variable_params' => 'item_variable_name' },
            join     => 'category',
        },
    );
    my %item_types_by_prevalence;
    map { push @{ $item_types_by_prevalence{ $_->prevalence } }, $_ } @item_types;

    while ( my $town = $town_rs->next ) {
        my @shops = _adjust_number_of_shops($town);

        foreach my $shop (@shops) {
            next unless $shop->status eq 'Open';

            _adjust_shops_modifier( $town, $shop );

            # Calculate items in shop
            my $ideal_items_value = $shop->shop_size * 50 + ( Games::Dice::Advanced->roll('1d40') - 20 );
            my $actual_items_value = 0;
            my @items_in_shop = $schema->resultset('Items')->search( { 'in_shop.shop_id' => $shop->id, }, { prefetch => [qw/item_type in_shop/], }, );

            # Remove some random items. This lets new items, or changes in prevalence, etc. have a chance to take affect
            @items_in_shop = _remove_random_items_from_shop(@items_in_shop);

            foreach my $item (@items_in_shop) {
                next unless defined $item;    # Might have removed some above
                $actual_items_value += $item->item_type->modified_cost($shop);
            }

            # TODO: add value of quantity items

            $logger->info( "Shop: " . $shop->id . ". ideal_value: $ideal_items_value, actual_value: $actual_items_value" );

            my $item_value_to_add = $ideal_items_value - $actual_items_value;

            while ( $item_value_to_add > 0 ) {
                my $min_prevalence = 100 - ( $town->prosperity + ( Games::Dice::Advanced->roll('1d40') - 20 ) );
                $min_prevalence = 100 if $min_prevalence > 100;
                $min_prevalence = 1   if $min_prevalence < 1;

                #warn "Min_prevalance: $min_prevalence\n";

                my $actual_prevalance = Games::Dice::Advanced->roll( '1d' . ( 100 - $min_prevalence ) ) + $min_prevalence;

                my $item_type;
                while ( !defined $item_type ) {
                    if ( $item_types_by_prevalence{$actual_prevalance} ) {
                        my @items = @{ $item_types_by_prevalence{$actual_prevalance} };
                        $item_type = $items[ Games::Dice::Advanced->roll( '1d' . scalar @items ) - 1 ];
                    }
                    else {
                        $actual_prevalance++;
                        last if $actual_prevalance > 100;
                    }
                }

                # We couldn't find a suitable item. Could've been a bad roll for min_prevalence. Try again
                next unless $item_type;

                # If the item_type has a 'quantity' variable param, add as an 'item made' rather than an
                #  individual item
                if ( my $variable_param = $item_type->variable_param('Quantity') ) {
                    my $items_made = $schema->resultset('Items_Made')->find_or_new(
                        {
                            item_type_id => $item_type->id,
                            shop_id      => $shop->id,
                        }
                    );

                    if ( $items_made->in_storage ) {

                        # Already make this item, try again.
                        next;
                    }
                    else {
                        $items_made->insert;
                    }

                    # The value of this item is the median of the range of in the 'bundle' times the
                    #  modified cost
                    my $median_value = ( $variable_param->max_value - $variable_param->min_value ) / 2 + $variable_param->min_value;
                    $item_value_to_add -= $item_type->modified_cost($shop) * $median_value;
                }
                else {
                    my $item = $schema->resultset('Items')->create(
                        {
                            item_type_id => $item_type->id,
                            shop_id      => $shop->id,
                        }
                    );

                    $item_value_to_add -= $item->item_type->modified_cost($shop);
                }
            }
        }
    }
}

sub _alter_statuses_of_shops {
    validate(
        @_,
        {
            number_to_change => 1,
            open_or_close    => { regex => qr/^Open|Close$/ },
            shops_by_status  => { type => HASHREF },
        }
    );

    my %params = @_;

    my $number_to_change = $params{number_to_change};
    my $open_or_close    = $params{open_or_close};
    my %shops_by_status  = %{ $params{shops_by_status} };

    my @order;
    if ( $open_or_close eq 'Open' ) {
        @order = qw/Closing Opening Open/;
    }
    else {
        @order = qw/Open Closing Closed/;

        # For our purposes, Opening and Open shops are the same
        #  (altho Opening shops are dealt to first)
        $shops_by_status{Open} = [ @{ $shops_by_status{Opening} || [] }, @{ $shops_by_status{Open} || [] } ];
    }

    my $order_index = 0;
OUTER: foreach my $status_to_change (@order) {

        #warn "Changing status from: $status_to_change to: $order[$order_index+1]";

        if ( $shops_by_status{$status_to_change} ) {
            foreach my $shop_to_change ( @{ $shops_by_status{$status_to_change} } ) {

                #warn "Changing status for: " . $shop_to_change->id . "\n";

                $shop_to_change->status( $order[ $order_index + 1 ] );
                $shop_to_change->update;

                $number_to_change--;

                last OUTER if $number_to_change == 0;
            }
        }

        # We don't change the last item in the list
        $order_index++;
        last if $order_index == ( scalar @order ) - 1;
    }

    return $number_to_change;

}

my @owner_names;
my @suffixes;

sub generate_shop_name {
    my $config = shift;

    if ( !@owner_names ) {
        my $file = $config->{data_file_path} . 'shop_owner_names.txt';
        open( my $names_fh, '<', $file ) || die "Couldn't open names file: $file ($!)\n";
        @owner_names = <$names_fh>;
        close($names_fh);
        chomp @owner_names;
    }

    unless (@suffixes) {
        my $file = $config->{data_file_path} . 'shop_suffix.txt';
        open( my $names_fh, '<', $file ) || die "Couldn't open names file: $file ($!)\n";
        @suffixes = <$names_fh>;
        close($names_fh);
        chomp @suffixes;
    }

    @owner_names = shuffle @owner_names;

    my $prefix = $owner_names[0];

    @suffixes = shuffle @suffixes;
    my $suffix = $suffixes[0];

    return $prefix, $suffix;
}

sub _adjust_number_of_shops {
    my $town = shift;

    # Adjust number of shops, if necessary
    my $ideal_number_of_shops = int( $town->prosperity / $config->{prosperity_per_shop} );
    $ideal_number_of_shops = 1 if $ideal_number_of_shops < 1;    # Always at least one shop per town

    my @shops = $town->shops;
    my %shops_by_status;
    map { push @{ $shops_by_status{ $_->status } }, $_ } @shops;

    my $open_shops_count = defined $shops_by_status{Open} ? scalar @{ $shops_by_status{Open} } : 0;

    $logger->info( "Town_id: " . $town->id . ", Ideal: $ideal_number_of_shops, Open: $open_shops_count" );

    if ( $ideal_number_of_shops > $open_shops_count ) {

        # Open up some new shops
        my $shops_to_open = $ideal_number_of_shops - $open_shops_count;

        # Change status of existing shops
        $shops_to_open = _alter_statuses_of_shops(
            number_to_change => $shops_to_open,
            open_or_close    => 'Open',
            shops_by_status  => \%shops_by_status
        );

        # If there's still more left to open, create some new shops
        for ( 1 .. $shops_to_open ) {

            # Create some new 'Opening' shops
            my ( $shop_owner_name, $suffix ) = generate_shop_name($config);
            my $new_shop = $town->add_to_shops(
                {
                    shop_owner_name => $shop_owner_name,
                    shop_suffix     => $suffix,
                    status          => 'Open',
                    shop_size       => Games::Dice::Advanced->roll('1d10'),
                }
            );
            push @shops, $new_shop;
        }
    }
    elsif ( $ideal_number_of_shops < $open_shops_count ) {
        my $shops_to_close = $open_shops_count - $ideal_number_of_shops;

        # Close some shops
        $shops_to_close = _alter_statuses_of_shops(
            number_to_change => $shops_to_close,
            open_or_close    => 'Close',
            shops_by_status  => \%shops_by_status
        );
    }

    return @shops;

}

sub _adjust_shops_modifier {
    my $town = shift;
    my $shop = shift;

    # Calculate shop's cost_modifier
    # TODO: the 100 below is max prosperity, the 60 is range of cost modifiers.
    #  As the range is -30% to +30%, we subtract 30. These values should probably in the config
    my $new_modifier = sprintf '%.2f', ( $town->prosperity / ( 100 / 60 ) ) - 30;

    #warn "Unrandomised modifer: $new_modifier\n";

    # Apply a random component
    $new_modifier += Games::Dice::Advanced->roll('1d10') - 5;

    my $modifier_difference = $new_modifier - $shop->cost_modifier;

    # New modifier can't be too far away from the old one
    if ( abs($modifier_difference) > $config->{max_cost_modifier_change} ) {
        if ( $modifier_difference > 0 ) {
            $new_modifier = $shop->cost_modifier + $config->{max_cost_modifier_change};
        }
        else {
            $new_modifier = $shop->cost_modifier - $config->{max_cost_modifier_change};
        }
    }

    $logger->info( "Shop: " . $shop->id . " modifier changed from " . $shop->cost_modifier . " to $new_modifier" );

    $shop->cost_modifier($new_modifier);
    $shop->update;
}

sub _remove_random_items_from_shop {
    my @items_in_shop = @_;

    @items_in_shop = shuffle @items_in_shop;

    my $items_to_remove = Games::Dice::Advanced->roll('1d3');

    for my $item_index ( 0 .. $items_to_remove - 1 ) {
        next unless defined $items_in_shop[$item_index];
        $items_in_shop[$item_index]->delete;
        undef $items_in_shop[$item_index];
    }

    return @items_in_shop;

}

1;
