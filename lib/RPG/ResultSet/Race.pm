use strict;
use warnings;

package RPG::ResultSet::Race;

use base 'DBIx::Class::ResultSet';

use List::Util qw(shuffle);

sub random {
    my $self = shift;

    my @races = shuffle( $self->search() );

    return $races[0];
}

1;
