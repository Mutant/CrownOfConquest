package RPG::Schema::Role::ResourceConsumer;

use Moose::Role;

# Consume the resources required to build this structure from the groups provided
#  Returns 1 if there were enough resources, 0 otherwise
# TODO: role possibly not the best place for this? It's not really an instance thing
sub consume_items {
    my $self             = shift;
    my $groups           = shift;
    my %items_to_consume = @_;

    my $category = 'Resource';

    #  Get the party's equipment.
    my @equipment;
    foreach my $group (@$groups) {
        push @equipment, $group->get_equipment($category);
    }

    #  Go through the items, decreasing the needed counts.
    my @items_to_consume;
    foreach my $item (@equipment) {
        if ( defined $items_to_consume{ $item->item_type->item_type } and $items_to_consume{ $item->item_type->item_type } > 0 ) {
            my $quantity = $item->variable('Quantity') // 1;

            if ( $quantity <= $items_to_consume{ $item->item_type->item_type } ) {
                $items_to_consume{ $item->item_type->item_type } -= $quantity;
                $quantity = 0;
            } else {
                $quantity -= $items_to_consume{ $item->item_type->item_type };
                $items_to_consume{ $item->item_type->item_type } = 0;
            }
            push @items_to_consume, {
                item     => $item,
                quantity => $quantity
            };
        }
    }

    #  If any of the counts are non-zero, we didn't have enough of the item.
    foreach my $next_key ( keys %items_to_consume ) {
        if ( $items_to_consume{$next_key} > 0 ) {
            return 0;
        }
    }

    #  We had enough resources, so decrement quantities and possibly delete the items.
    foreach my $to_consume (@items_to_consume) {
        if ( $to_consume->{quantity} == 0 ) {
            if ( my $character = $to_consume->{item}->belongs_to_character ) {
                $character->remove_item_from_grid( $to_consume->{item} );
            }
            elsif ( my $garrison = $to_consume->{item}->garrison ) {
                $garrison->remove_item_from_grid( $to_consume->{item} );
            }

            $to_consume->{item}->delete;
        } else {
            my $var = $to_consume->{item}->variable_row('Quantity');
            $var->item_variable_value( $to_consume->{quantity} );
            $var->update;
        }
    }

    return 1;
}

1;
