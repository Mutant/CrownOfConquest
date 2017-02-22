use strict;
use warnings;

package RPG::ResultSet::Items;

use base 'DBIx::Class::ResultSet';

use List::Util qw(shuffle);

sub party_items_requiring_repair {
    my $self               = shift;
    my $party_id           = shift;
    my $only_eqipped_items = shift // 0;

    my %extra_params = map { 'belongs_to_character.' . $_ => undef } RPG::Schema::Character->in_party_columns;
    $extra_params{equip_place_id} = { '!=', undef } if $only_eqipped_items;

    return $self->search(
        {
            'item_variables.item_variable_value' => \'< item_variables.max_value',
            'item_variable_name.item_variable_name' => 'Durability',
            'belongs_to_character.party_id'         => $party_id,
            %extra_params,
        },
        { join => [ { 'item_variables' => 'item_variable_name' }, 'belongs_to_character' ], }
    );
}

sub party_items_in_category {
    my $self        = shift;
    my $party_id    = shift;
    my $category_id = shift;

    my %extra_params = map { 'belongs_to_character.' . $_ => undef } RPG::Schema::Character->in_party_columns;

    return $self->search(
        {
            'belongs_to_character.party_id' => $party_id,
            'item_type.item_category_id'    => $category_id,
            %extra_params,
        },
        {
            prefetch => [ 'belongs_to_character', 'item_type', { 'item_variables', => 'item_variable_name' }, ],
            order_by => 'belongs_to_character.party_order',
            distinct => 1,
        },
    );

}

sub create_enchanted {
    my $self         = shift;
    my $params       = shift;
    my $extra_params = shift;

    my $item;
    my $creation_tries = 0;

    while ( !defined $item ) {
        $item = $self->create($params);

        return $item if !defined $extra_params->{number_of_enchantments} || $extra_params->{number_of_enchantments} == 0;

        my @possible_enchantments;

        if ( $extra_params->{enchantment_to_create} ) {
            my $enchantment = $self->result_source->schema->resultset('Enchantments')->find(
                {
                    enchantment_name => $extra_params->{enchantment_to_create},
                },
            );
            @possible_enchantments = ($enchantment);
        }
        else {
            @possible_enchantments = $self->result_source->schema->resultset('Enchantments')->search(
                {
                    'categories.item_category_id' => $item->item_type->item_category_id,
                },
                {
                    join => 'categories',
                }
            );
        }

        return $item unless @possible_enchantments;

        for ( 1 .. $extra_params->{number_of_enchantments} ) {
            last unless @possible_enchantments;

            @possible_enchantments = shuffle @possible_enchantments;

            my $enchantment = $possible_enchantments[0];

            shift @possible_enchantments if $enchantment->one_per_item;

            $item->add_to_item_enchantments(
                {
                    enchantment_id => $enchantment->id,
                }
            );
        }

        $creation_tries++;

        if ( defined $extra_params->{max_value} && $item->sell_price > $extra_params->{max_value} ) {
            if ( $creation_tries > 10 ) {

                # Tried 10 times, but still don't have an item under max_value!
                #  Just create something without an enchantment
                return $self->create($params);
            }

            # Item worth more then max_value. Delete it and start again
            $item->delete;
            undef $item;
        }
    }

    return $item;
}

1;
