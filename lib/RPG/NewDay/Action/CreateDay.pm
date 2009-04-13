package RPG::NewDay::Action::CreateDay;
use Mouse;

extends 'RPG::NewDay::Base';

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    # Create a new day
    my $yesterday = $c->schema->resultset('Day')->find(
        {},
        {
            'select' => { max => 'day_number' },
            'as'     => 'day_number'
        },
        )->day_number
        || 1;

    my $new_day = $c->schema->resultset('Day')->create(
        {
            'day_number'   => $yesterday + 1,
            'game_year'    => 100,              # TODO: generate game year as well
            'date_started' => $c->datetime,
        },
    );
    
    $c->current_day($new_day);

    $c->logger->info( "Beginning new day script for day: " . $new_day->day_number );   
}