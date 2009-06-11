package RPG::Schema::Quest::Raid_Town;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use RPG::Map;
use List::Util qw(shuffle);
use Data::Dumper;
use Games::Dice::Advanced;

sub set_quest_params {
    my $self = shift;

    my $town          = $self->town;
    my $town_location = $town->location;

    my @towns_in_range = $self->result_source->schema->resultset('Town')->find_in_range(
        {
            x => $town_location->x,
            y => $town_location->y,
        },
        $self->{_config}{initial_search_range},
        2,
    );

    if ( scalar @towns_in_range < 1 ) {
        $self->delete;
        die RPG::Exception->new(
            message => "Can't create raid town quest - no suitable towns to raid within range of town",
            type    => 'quest_creation_error',
        );
    }

    @towns_in_range = shuffle @towns_in_range;
    my $town_to_raid = $towns_in_range[0];

    # Check for existing quests in this town to raid or send a message to the target town
    my $existing_quest_count = $self->result_source->schema->resultset('Quest')->search(
        {
            town_id            => $town->id,
            'quest_param_name' => [ 'Town To Raid', 'Town To Take Msg To' ],
            'start_value'      => $town_to_raid->id,
        },
        { join => [ 'type', { 'quest_params' => 'quest_param_name', } ], }
    )->count;

    if ( $existing_quest_count > 0 ) {
        $self->delete;
        die RPG::Exception->new(
            message => "Target town is already targetted in another quest",
            type    => 'quest_creation_error',
        );
    }

    $self->define_quest_param( 'Town To Raid', $town_to_raid->id );
    $self->define_quest_param( 'Raided Town',  0 );

    my $distance = RPG::Map->get_distance_between_points(
        {
            x => $town_location->x,
            y => $town_location->y,
        },
        {
            x => $town_to_raid->location->x,
            y => $town_to_raid->location->y,
        },
    );

    # Best not to make the gold value based purely on distance, or people will be able to guess how far away the town is
    my $gold_variant = Games::Dice::Advanced->roll('1d100') - 50;
    my $gold_value   = $self->{_config}{gold_per_distance} * $distance - $gold_variant;
    $gold_value = 20 if $gold_value < 20;

    $self->gold_value($gold_value);
    $self->xp_value( $self->{_config}{xp_per_distance} * $distance );
    $self->min_level( $self->{_config}{min_level} );

    my $days_to_complete = $distance;
    $days_to_complete += Games::Dice::Advanced->roll('1d4') - 2;
    $days_to_complete = 4 if $days_to_complete < 4;

    $self->days_to_complete($days_to_complete);

    $self->update;

}

sub check_action {
    my $self        = shift;
    my $party       = shift;
    my $action      = shift;
    my $town_raided = shift;

    return 0 unless $action eq 'town_raid';

    return 0 if $self->param_current_value('Raided Town') == 1;

    return 0 unless $town_raided == $self->param_start_value('Town To Raid');

    my $quest_param = $self->param_record('Raided Town');
    $quest_param->current_value(1);
    $quest_param->update;

    return 1;
}

sub ready_to_complete {
    my $self = shift;

    return $self->param_current_value('Raided Town');
}

sub town_to_raid {
    my $self = shift;

    return $self->result_source->schema->resultset('Town')->find( $self->param_start_value('Town To Raid') );
}

1;
