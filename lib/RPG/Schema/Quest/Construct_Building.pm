package RPG::Schema::Quest::Construct_Building;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

sub set_quest_params {
    my $self = shift;
    
    # Find a sector for the building
    my $range_rec = $self->find_related(
        'kingdom',
        {},
        {
            select => [ { min => 'x' }, { min => 'y' }, { max => 'x' }, { max => 'y' }, ],
            as     => [qw/min_x min_y max_x max_y/],
        },
    );
    
    
    
}

1;