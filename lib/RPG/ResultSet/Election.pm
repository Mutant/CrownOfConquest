use strict;
use warnings;

package RPG::ResultSet::Election;

use base 'DBIx::Class::ResultSet';

use Carp;

sub schedule {
    my $self = shift;
    my $town = shift || croak "Town not supplied";
    my $days = shift || croak "Number of days not supplied";

    croak "Already have an election scheduled\n" if $town->current_election;

    my $mayor = $town->mayor;

    croak "No mayor in this town" unless $mayor;

    croak "Invalid day\n" if $days < 3;

    my $schema = $self->result_source->schema;

    my $today = $schema->resultset('Day')->find_today;

    my $day = $today->day_number + $days;

    my $election = $self->create(
        {
            town_id       => $town->id,
            scheduled_day => $day,
            status        => 'Open',
        }
    );

    $schema->resultset('Election_Candidate')->create(
        {
            character_id => $mayor->id,
            election_id  => $election->id,
        },
    );

    $schema->resultset('Town_History')->create(
        {
            town_id => $town->id,
            day_id  => $today->id,
            message => $mayor->name . " has called an election for day $day. " . ucfirst $mayor->pronoun('subjective')
              . " invites prospective candidates to register to run.",
        }
    );

    $schema->resultset('Global_News')->create(
        {
            day_id => $today->id,
            message => "The town of " . $town->town_name . " has scheduled an election for day $day.",
        },
    );

    return $election;
}

1;
