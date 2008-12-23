package RPG::C::Party::Details;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details.html',
                params   => { party => $c->stash->{party}, },
            }
        ]
    );
}

sub history : Local {
    my ( $self, $c ) = @_;

    # Check if new day message should be displayed
    my @day_logs = $c->model('DBIC::DayLog')->search(
        { 'party_id' => $c->stash->{party}->id, },
        {
            order_by => 'day.date_started desc',
            prefetch => 'day',
            rows     => 7,                         # TODO: config me
        },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/history.html',
                params   => { day_logs => \@day_logs, },
            }
        ]
    );

}

sub options : Local {
    my ( $self, $c ) = @_;
        
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/options.html',
                params   => {  },
            }
        ]
    );
}

1;
