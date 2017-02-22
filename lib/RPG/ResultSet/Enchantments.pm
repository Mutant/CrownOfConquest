use strict;
use warnings;

package RPG::ResultSet::Enchantments;

use base 'DBIx::Class::ResultSet';

use List::Util qw(shuffle);

sub random {
    my $self = shift;

    my @class = shuffle( $self->search() );

    return $class[0];
}

1;
