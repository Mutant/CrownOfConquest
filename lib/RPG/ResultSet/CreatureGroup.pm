use strict;
use warnings;

package RPG::ResultSet::CreatureGroup;

use base 'DBIx::Class::ResultSet';

sub get_by_id {
    my $self              = shift;
    my $creature_group_id = shift;

    my $creature_group = $self->find(
        { creature_group_id => $creature_group_id, },
        {
            prefetch => { 'creatures' => [ 'type', 'creature_effects' ] },
        },
    );

    return $creature_group;

}

1;
