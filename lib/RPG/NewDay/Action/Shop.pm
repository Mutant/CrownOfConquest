package RPG::NewDay::Action::Shop;

use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;

use Games::Dice::Advanced;
use Params::Validate qw(:types validate);
use List::Util qw(shuffle);

sub depends { qw/RPG::NewDay::Action::Town/ }

sub run {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search( {}, { prefetch => 'shops' } );

    # Get list of item types, as we only need to get it once
    my @item_types = $c->schema->resultset('Item_Type')->search(
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
        my @shops = $self->_adjust_number_of_shops($town);

        foreach my $shop (@shops) {
            next unless $shop->status eq 'Open';

            # Calculate items in shop
            my $ideal_items_value = $shop->shop_size * 250 + ( Games::Dice::Advanced->roll('2d40') - 20 );
            my $actual_items_value = 0;
            my @items_in_shop =
                $c->schema->resultset('Items')->search( { 'in_shop.shop_id' => $shop->id, }, { prefetch => [qw/item_type in_shop/], }, );
                
            my @items_made = $shop->item_types_made;

            # Remove some random items. This lets new items, or changes in prevalence, etc. have a chance to take effect
            my @removed = $self->_remove_random_items_from_shop($shop, @items_in_shop, @items_made);

            # Calculate value of items
            foreach my $item (@items_in_shop) {
                # Skip item if it's just been deleted
                next if scalar (grep { $_->isa('RPG::Schema::Item') && $_->id == $item->id } @removed) > 1;
                $actual_items_value += $item->item_type->modified_cost($shop);
            }

            # Add value of quantity items
            foreach my $item_type (@items_made) {
                # Skip item type if it's just been deleted
                next if scalar (grep { $_->isa('RPG::Schema::Item_Type') && $_->id == $item_type->id } @removed) > 1;
                                
                $actual_items_value += $item_type->modified_cost($shop);
            }

            my $item_value_to_add = $ideal_items_value - $actual_items_value;

            $c->logger->info( "Shop: " . $shop->id . ". ideal_value: $ideal_items_value, actual_value: $actual_items_value, to add $item_value_to_add" );

            my $added_count = 0;
            my $retries = 0;

            while ( $item_value_to_add > 0 ) {
                my $min_prevalence = 100 - ($town->prosperity + Games::Dice::Advanced->roll('1d10') ) - 20;
                $min_prevalence = 80 if $min_prevalence > 100;
                $min_prevalence = 1   if $min_prevalence < 1;

                my $actual_prevalance = Games::Dice::Advanced->roll( '1d' . ( 100 - $min_prevalence ) ) + $min_prevalence;
                $actual_prevalance = 100 if $actual_prevalance > 100;

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
                if (! $item_type) {
                    $retries++;
                    last if $retries > 50;
                    next;   
                }
                
                $added_count++;

                # If the item_type has a 'quantity' variable param, add as an 'item made' rather than an
                #  individual item
                if ( my $variable_param = $item_type->variable_param('Quantity') ) {
                    my $items_made = $c->schema->resultset('Items_Made')->find_or_new(
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

                    $item_value_to_add -= $item_type->modified_cost($shop);
                }
                else {
                	my $number_of_enchantments = 0;
                	if (Games::Dice::Advanced->roll('1d100') <= $c->config->{shop_enchanted_item_chance}) {
                		$number_of_enchantments = RPG::Maths->weighted_random_number(1..3);	
                	}
                	
                    my $item = $c->schema->resultset('Items')->create_enchanted(
                        {
                            item_type_id => $item_type->id,
                            shop_id      => $shop->id,
                        },
                        {
                        	number_of_enchantments => $number_of_enchantments,
                        }                        
                    );

                    $item_value_to_add -= $item->sell_price($shop, 0);
                }
            }
            
            $c->logger->info("Added $added_count items (value left to add: $item_value_to_add)");
            
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

    my %next_status;
    my @order_to_check;
    if ( $open_or_close eq 'Open' ) {
        %next_status = (
            'Closed'  => 'Opening',
            'Closing' => 'Opening',
            'Opening' => 'Open',
        );
        @order_to_check = qw/Opening Closing Closed/;
    }
    else {
        %next_status = (
            'Closing' => 'Closed',
            'Opening' => 'Closing',
            'Open'    => 'Closing',
        );
        @order_to_check = qw/Closing Opening Open/;
    }

    OUTER: foreach my $status_to_change (@order_to_check) {

        #warn "Changing status from: $status_to_change to: $next_status{$status_to_change}";

        if ( $shops_by_status{$status_to_change} ) {
            foreach my $shop_to_change ( @{ $shops_by_status{$status_to_change} } ) {

                #warn "Changing status for: " . $shop_to_change->id . "\n";

                $shop_to_change->status( $next_status{$status_to_change} );
                $shop_to_change->update;

                $number_to_change--;

                last OUTER if $number_to_change == 0;
            }
        }
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
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    # Adjust number of shops, if necessary
    my $ideal_number_of_shops = int( $town->prosperity / $c->config->{prosperity_per_shop} );
    $ideal_number_of_shops = 1 if $ideal_number_of_shops < 1;    # Always at least one shop per town

    my @shops = $town->shops;
    my %shops_by_status;
    map { push @{ $shops_by_status{ $_->status } }, $_ } @shops;

    my $open_shops_count = defined $shops_by_status{Open} ? scalar @{ $shops_by_status{Open} } : 0;

    #warn "Town_id: " . $town->id . ", Ideal: $ideal_number_of_shops, Open: $open_shops_count";
    $c->logger->info( "Town_id: " . $town->id . ", Ideal: $ideal_number_of_shops, Open: $open_shops_count" );

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
            my ( $shop_owner_name, $suffix ) = generate_shop_name( $c->config );
            my $new_shop = $town->add_to_shops(
                {
                    shop_owner_name => $shop_owner_name,
                    shop_suffix     => $suffix,
                    status          => 'Opening',
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
    else {
        # Closing shops should close, closed shops should be deleted
        foreach my $shop (@shops) {
            if ($shop->status eq 'Closing') {
                $shop->status('Closed');
                $shop->update;   
            }
            elsif ($shop->status eq 'Closed') {
            	$shop->delete;	
            }
        } 
    }

    return @shops;

}

sub _remove_random_items_from_shop {
    my $self = shift;
    my $shop = shift;
    my @items_in_shop = @_;

    @items_in_shop = shuffle @items_in_shop;

    my $items_to_remove = Games::Dice::Advanced->roll('1d4') - 1;

    my @removed;
    
    my $deleted_count = 0;
    my $value = 0;

    for my $item_index ( 1 .. $items_to_remove ) {
        my $item = shift @items_in_shop;
        next unless $item;
        
        if ($item->isa('RPG::Schema::Items')) {
            $value += $item->item_type->modified_cost($shop);
            $item->delete;
        }
        else {
            $value += $item->modified_cost($shop);
            $self->context->schema->resultset('Items_Made')->find(
                {
                    item_type_id => $item->id,
                    shop_id => $shop->id,
                }
            );
            
        }
        
        $deleted_count++;
        push @removed, $item;
        
    }

    $self->context->logger->info("Deleted $deleted_count items (value: $value)");

    return @removed;

}

__PACKAGE__->meta->make_immutable;


1;
