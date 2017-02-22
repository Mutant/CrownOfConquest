use strict;
use warnings;

package RPG::ResultSet::Item_Type;

use base 'DBIx::Class::ResultSet';

sub get_by_prevalence {
    my $self = shift;

    my %item_types_by_prevalence;

    my @item_types = $self->search(
        {
            'category.hidden'   => 0,
            'category.findable' => 1,
        },
        {
            prefetch => { 'item_variable_params' => 'item_variable_name' },
            join => 'category',
        },
    );
    map { push @{ $item_types_by_prevalence{ $_->prevalence } }, $_ } @item_types;

    return %item_types_by_prevalence;
}

1;
