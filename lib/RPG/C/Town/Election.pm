package RPG::C::Town::Election;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->stash->{town} = $c->stash->{party_location}->town;

    croak "Party not in a town" unless $c->stash->{town};

    $c->stash->{election} = $c->stash->{town}->current_election;

    croak "No election in town" unless $c->stash->{election};
}

sub default : Local {
    my ( $self, $c ) = @_;

    my @candidates = $c->stash->{election}->candidates;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/election.html',
                params   => {
                    election   => $c->stash->{election},
                    candidates => \@candidates,
                    town       => $c->stash->{town},
                    tab        => $c->flash->{tab} || '',
                    error      => $c->flash->{error} || '',
                },
            }
        ]
    );
}

sub campaign : Local {
    my ( $self, $c ) = @_;

    my $new_candidates_allowed = 1;
    if ( $c->stash->{election}->scheduled_day - $c->stash->{today}->day_number <= $c->config->{min_days_for_election_candidacy} ) {
        $new_candidates_allowed = 0;
    }

    my $candidate = $c->model('DBIC::Character')->find(
        {
            'election.town_id' => $c->stash->{town}->id,
            'party_id'         => $c->stash->{party}->id,
            'election.status'  => 'Open',
        },
        {
            join => { 'mayoral_candidacy' => 'election' },
        }
    );

    my $candidacy;
    $candidacy = $c->model('DBIC::Election_Candidate')->find(
        {
            'election_id'  => $c->stash->{election}->id,
            'character_id' => $candidate->character_id,
        }
    ) if $candidate;

    # If they don't have a candidate already, see if they have any chars that qualify
    my @allowed_candidates;
    unless ( $candidate && $new_candidates_allowed ) {
        foreach my $character ( $c->stash->{party}->members ) {
            if ( $character->level >= $c->config->{min_character_mayoral_candidate_level} && $character->is_in_party ) {
                push @allowed_candidates, $character;
            }
        }
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/election/campaign.html',
                params   => {
                    candidate              => $candidate,
                    candidacy              => $candidacy,
                    town                   => $c->stash->{town},
                    allowed_candidates     => \@allowed_candidates,
                    new_candidates_allowed => $new_candidates_allowed,
                    party                  => $c->stash->{party},
                },
            }
        ]
    );
}

sub create_candidate : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        }
    );

    croak "Invalid character" if !$character || !$character->is_in_party;

    $c->model('DBIC::Election_Candidate')->create(
        {
            character_id => $character->id,
            election_id  => $c->stash->{election}->id,
        },
    );

    $character->status('inn');
    $character->status_context( $c->stash->{town}->id );
    $character->update;

    $c->model('DBIC::Town_History')->create(
        {
            town_id => $c->stash->{town}->id,
            day_id  => $c->stash->{today}->id,
            message => $character->name . " announces " . $character->pronoun('posessive-subjective') . " candidacy for the upcoming election",
        }
    );

    $c->flash->{tab} = 'campaign';

    $c->forward( '/panel/refresh', [ [ screen => 'town/election' ], 'party' ] );
}

sub add_to_spend : Local {
    my ( $self, $c ) = @_;

    croak "Invalid amount" if $c->req->param('campaign_spend') < 0;

    $c->flash->{tab} = 'campaign';

    if ( $c->req->param('campaign_spend') > $c->stash->{party}->gold ) {
        $c->stash->{panel_messages} = "You don't have enough gold to spend that much on the campaign";

        $c->forward('/panel/refresh');

        return;
    }

    my $candidate = $c->model('DBIC::Character')->find(
        {
            'election.town_id' => $c->stash->{town}->id,
            'party_id'         => $c->stash->{party}->id,
            'election.status'  => 'Open',
        },
        {
            join => { 'mayoral_candidacy' => 'election' },
        }
    );

    croak "No candidate for this election" unless $candidate;

    my $candidacy = $c->model('DBIC::Election_Candidate')->find(
        {
            'election_id'  => $c->stash->{election}->id,
            'character_id' => $candidate->character_id,
        }
    );

    if ( $candidacy->max_spend < $candidacy->campaign_spend + $c->req->param('campaign_spend') ) {
        $c->stash->{panel_messages} = "Spending this much would exceed your maximum allowed spend for this campaign";

        $c->forward('/panel/refresh');

        return;
    }

    $candidacy->increase_campaign_spend( $c->req->param('campaign_spend') );
    $candidacy->update;

    $c->stash->{party}->decrease_gold( $c->req->param('campaign_spend') );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ [ screen => 'town/election' ], 'party_status' ] );
}

sub poll : Local {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/election/poll.html',
                params   => {},
            }
        ]
    );
}

sub run_poll : Local {
    my ( $self, $c ) = @_;

    my $spend = $c->req->param('poll_spend') || 1;

    if ( $c->stash->{party}->gold < $spend ) {
        $c->res->body("You do not have enough gold");
        return;
    }

    $c->stash->{party}->decrease_gold($spend);
    $c->stash->{party}->update;

    my %scores = $c->stash->{election}->get_scores;

    my $pop_modifer = $c->stash->{town}->prosperity * 10;

    my $accuracy = $spend / $c->stash->{town}->prosperity * 4;
    $accuracy = 95 if $accuracy > 95;

    my $dice_size = int 100 - $accuracy;

    my @results;
    foreach my $char_id ( keys %scores ) {
        my $poll_result = int $scores{$char_id}->{total} * $pop_modifer;

        my $fudge = ( Games::Dice::Advanced->roll( '1d' . $dice_size ) - int( $dice_size / 2 ) ) / 100;

        $poll_result += int $poll_result * $fudge;
        $poll_result = 0 if $poll_result < 0;

        push @results, { result => $poll_result, character => $scores{$char_id}->{character} };
    }

    @results = sort { $b->{result} <=> $a->{result} } @results;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/election/poll_result.html',
                params   => {
                    results => \@results,
                },
            }
        ]
    );
}

1;
