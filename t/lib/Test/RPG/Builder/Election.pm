use strict;
use warnings;

package Test::RPG::Builder::Election;

use Test::RPG::Builder::Character;

sub build_election {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $election = $schema->resultset('Election')->create(
        {
            scheduled_day => $params{scheduled_day} || 100,
            status        => 'Open',
            town_id       => $params{town_id},
        }
    );

    if ( $params{candidate_count} ) {
        for ( 1 .. $params{candidate_count} ) {
            my $character = Test::RPG::Builder::Character->build_character(
                $schema,
                level => $params{character_level} || 1,
                %params,
            );

            $schema->resultset('Election_Candidate')->create(
                {
                    character_id => $character->id,
                    election_id  => $election->id,
                },
            );
        }
    }

    return $election;
}

1;
