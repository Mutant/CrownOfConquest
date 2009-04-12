package RPG::Schema::Quest::Msg_To_Town;

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

    @towns_in_range = shuffle @towns_in_range;

    $self->define_quest_param( 'Town To Take Msg To', $towns_in_range[0]->id );
    $self->define_quest_param( 'Been To Town',        0 );

    my $distance = RPG::Map->get_distance_between_points(
        {
            x => $town_location->x,
            y => $town_location->y,
        },
        {
            x => $towns_in_range[0]->location->x,
            y => $towns_in_range[0]->location->y,
        },
    );

    # Best not to make the gold value based purely on distance, or people will be able to guess how far away the town is
    my $gold_variant = Games::Dice::Advanced->roll('1d100') - 50;
    my $gold_value   = $self->{_config}{gold_per_distance} * $distance - $gold_variant;
    $gold_value = 20 if $gold_value < 20;

    $self->gold_value($gold_value);
    $self->xp_value( $self->{_config}{xp_per_distance} * $distance );

    my $days_to_complete = $distance;
    $days_to_complete += Games::Dice::Advanced->roll('1d4') - 2;
    $days_to_complete = 4 if $days_to_complete < 4;

    $self->days_to_complete($days_to_complete);

    $self->update;

}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;

    return 0 unless $action eq 'townhall_visit';

    return 0 if $self->param_current_value('Been To Town') == 1;

    return 0 unless $party->location->town->id == $self->param_start_value('Town To Take Msg To');

    my $quest_param = $self->param_record('Been To Town');
    $quest_param->current_value(1);
    $quest_param->update;

    return 1;
}

sub ready_to_complete {
    my $self = shift;

    return $self->param_current_value('Been To Town');
}

sub town_to_take_msg_to {
    my $self = shift;

    return $self->result_source->schema->resultset('Town')->find( $self->param_start_value('Town To Take Msg To') );
}

1;
