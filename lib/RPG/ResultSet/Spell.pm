use strict;
use warnings;

package RPG::ResultSet::Spell;

use base 'DBIx::Class::ResultSet';

use List::Util qw(shuffle);

sub random {
    my $self   = shift;
    my %params = @_;

    my @spells = shuffle( $self->search(
            {
                hidden => 0,
                spell_name => { '!=', $params{exclude} },
            },
    ) );

    return $spells[0];
}

1;
