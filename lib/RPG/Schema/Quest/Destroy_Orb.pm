package RPG::Schema::Quest::Destroy_Orb;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use RPG::Exception;

use List::Util qw(shuffle);
use Data::Dumper;
use Games::Dice::Advanced;
use Scalar::Util 'blessed';

sub set_quest_params {
    my $self = shift;

    my $town          = $self->town;
    my $town_location = $town->location;

    my $orb_to_destroy;

    my $search_range = $self->{_config}{initial_search_range};

    my $tries = 0;
    while ( !defined $orb_to_destroy ) {
        my @orbs_in_range;

        eval {
            @orbs_in_range = $self->result_source->schema->resultset('Creature_Orb')->find_in_range(
                {
                    x => $town_location->x,
                    y => $town_location->y,
                },
                $search_range,
                2,
                $self->{_config}{max_search_range},
            );
        };
        if ( my $ev_err = $@ ) {
            if ( blessed($ev_err) && $ev_err->isa("RPG::Exception") ) {
                $self->delete;
                die RPG::Exception->new(
                    message => "Can't create quest - no Orbs within range of town",
                    type    => 'quest_creation_error',
                );
            }
            else {
                die $@;
            }
        }

        @orbs_in_range = shuffle @orbs_in_range;

        $orb_to_destroy = shift @orbs_in_range;

        # See if there's already a quest for this Orb in this town
        my $existing_quest = $self->result_source->schema->resultset('Quest')->find(
            {
                quest_type_id                       => $self->quest_type_id,
                town_id                             => $town->id,
                'quest_param_name.quest_param_name' => 'Orb To Destroy',
                'quest_params.start_value'          => $orb_to_destroy->id,
            },
            { join => { 'quest_params' => 'quest_param_name' }, }
        );
        
        # A quest for this orb already exists in this town. Try increasing the initial search range.
        #  This makes sure we don't just get the same orb back. But it does mean we could keep searching forever,
        #   which we prevent by having a maximum number of times we'll try this before throwing an exception
        if ($existing_quest) { 
            $tries++;
            $search_range += 2;

            if ( $tries > 3 ) {
                $self->delete;
                die RPG::Exception->new(
                    message => "Can't create quest - no suitable Orbs within range of town",
                    type    => 'quest_creation_error',
                );
            }
                    
            undef $orb_to_destroy;
        }
    }

    $self->define_quest_param( 'Orb To Destroy', $orb_to_destroy->id );
    $self->define_quest_param( 'Destroyed Orb',  0 );

    my $distance = RPG::Map->get_distance_between_points(
        {
            x => $town_location->x,
            y => $town_location->y,
        },
        {
            x => $orb_to_destroy->land->x,
            y => $orb_to_destroy->land->y,
        },
    );

    # Best not to make the gold value based purely on distance, or people will be able to guess how far away the orb is
    my $gold_variant = Games::Dice::Advanced->roll('1d100') - 50;
    my $gold_value   = $self->{_config}{gold_per_distance} * $distance * $orb_to_destroy->level - $gold_variant;
    $gold_value = 20 if $gold_value < 20;

    $self->min_level( $orb_to_destroy->level * 3 );
    $self->gold_value($gold_value);
    $self->xp_value( $self->{_config}{xp_per_distance} * $distance * $orb_to_destroy->level );

    my $days_to_complete = $distance;
    $days_to_complete += Games::Dice::Advanced->roll('1d4') - 2;
    $days_to_complete = 4 if $days_to_complete < 4;

    $self->days_to_complete($days_to_complete);
    $self->update;
}

sub interested_in_actions {
    my $self = shift;

    # Interested in Orbs being destroyed, to terminate the quest
    return 'orb_destroyed';
}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;
    my $orb_id = shift;

    return 0 unless $action eq 'orb_destroyed';

    return 0 unless $orb_id == $self->param_start_value('Orb To Destroy');

    my $quest_param = $self->param_record('Destroyed Orb');
    $quest_param->current_value(1);
    $quest_param->update;

    return 1;
}

sub check_action_from_another_party {
    my $self                 = shift;
    my $party_that_triggered = shift;
    my $action               = shift;
    my $orb_id               = shift;

    return 0 unless $action eq 'orb_destroyed';

    return 0 unless $orb_id == $self->param_start_value('Orb To Destroy');

    if ( $self->status eq 'In Progress' ) {
        return 0 if $party_that_triggered->id == $self->party->id;

        # Another party has destoryed the Orb. Terminate the quest, and leave a message for this party.
        $self->status('Terminated');
        $self->update;

        my $today = $self->result_source->schema->resultset('Day')->find(
            {},
            {
                'rows'     => 1,
                'order_by' => 'day_number desc'
            },
        );

        $self->result_source->schema->resultset('Party_Messages')->create(
            {
                party_id => $self->party->id,
                message  => "The town of "
                    . $self->town->town_name
                    . " sends you a message that the party known as "
                    . $party_that_triggered->name . " has "
                    . "destroyed the Orb of "
                    . $self->orb_to_destroy->name
                    . ". Your quest has therefore been terminated amicably.",
                alert_party => 1,
                day_id      => $today->id,
            }
        );
    }
    elsif ( $self->status eq 'Not Started' ) {
        $self->delete;
    }

    return 1;
}

sub ready_to_complete {
    my $self = shift;

    return $self->param_current_value('Destroyed Orb');
}

sub orb_to_destroy {
    my $self = shift;

    return $self->result_source->schema->resultset('Creature_Orb')->find( $self->param_start_value('Orb To Destroy') );
}

sub direction_from_town_to_orb {
    my $self = shift;

    my $orb =
        $self->result_source->schema->resultset('Creature_Orb')
        ->find( { creature_orb_id => $self->param_start_value('Orb To Destroy'), }, { prefetch => 'land', } );

    return unless $orb;

    return RPG::Map->get_direction_to_point(
        {
            x => $self->town->location->x,
            y => $self->town->location->y,
        },
        {
            x => $orb->land->x,
            y => $orb->land->y,
        }
    );
}

1;
