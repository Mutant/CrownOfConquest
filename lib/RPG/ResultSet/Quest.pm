use strict;
use warnings;

package RPG::ResultSet::Quest;

use base 'DBIx::Class::ResultSet';

use RPG::Schema::Quest;

sub find_quests_by_interested_action {
    my $self   = shift;
    my $action = shift;

    my @interested_types;
    my %actions_by_quest_type = RPG::Schema::Quest->interested_actions_by_quest_type();
    while ( my ( $type, $actions ) = each %actions_by_quest_type ) {
        if ( grep { $_ eq $action } @$actions ) {
            push @interested_types, $type;
        }
    }

    return unless @interested_types;

    return $self->search(
        {
            'type.quest_type' => \@interested_types,
            'status' => [ 'Not Started', 'In Progress' ],
        },
        {
            'prefetch' => [ { 'type' => 'quest_param_names' }, 'quest_params' ],
        }
    );
}

1;
