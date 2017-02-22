package RPG::NewDay::Action::CreateDay;
use Moose;

use File::Copy;

extends 'RPG::NewDay::Base';

sub continue_on_error {
    return 0;
}

sub run {
    my $self = shift;

    my $c = $self->context;

    # Create a new day
    my $yesterday_day_num = $c->schema->resultset('Day')->find(
        {},
        {
            'select' => { max => 'day_number' },
            'as' => 'day_number'
        },
    )->day_number || 1;

    my $yesterday = $c->schema->resultset('Day')->find(
        {
            day_number => $yesterday_day_num
        }
    );

    my $new_day = $c->schema->resultset('Day')->create(
        {
            'day_number' => $yesterday_day_num + 1,
            'game_year'    => 100,            # TODO: generate game year as well
            'date_started' => $c->datetime,
        },
    );

    $c->yesterday($yesterday);
    $c->current_day($new_day);

    copy( $c->config->{home} . '/docroot/static/minimap/kingdoms.png', $c->config->{home} . '/docroot/static/minimap/' . $new_day->day_number . '.png' );

    $c->logger->info( "Beginning new day script for day: " . $new_day->day_number );
}

__PACKAGE__->meta->make_immutable;

1;
