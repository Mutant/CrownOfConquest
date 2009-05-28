package RPG::NewDay::Action::CreateDay;
use Moose;

extends 'RPG::NewDay::Base';

sub run {
    my $self = shift;

    my $c = $self->context;

    # Create a new day
    my $yesterday_day_num = $c->schema->resultset('Day')->find(
        {},
        {
            'select' => { max => 'day_number' },
            'as'     => 'day_number'
        },
    )->day_number || 1;

    my $yesterday = $c->schema->resultset('Day')->find(
        {
            day_number => $yesterday_day_num
        }
    );

    my $new_day = $c->schema->resultset('Day')->create(
        {
            'day_number'   => $yesterday_day_num + 1,
            'game_year'    => 100, # TODO: generate game year as well
            'date_started' => $c->datetime,
        },
    );

    $c->yesterday($yesterday);
    $c->current_day($new_day);

    $c->logger->info( "Beginning new day script for day: " . $new_day->day_number );
}
