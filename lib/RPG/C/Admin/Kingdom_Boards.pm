package RPG::C::Admin::Kingdom_Boards;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub view : Local {
    my ( $self, $c ) = @_;

    my @kingdoms = $c->model('DBIC::Kingdom')->search(
        {
            active => 1,
        },
    );
    my $kingdom;

    if ( !$c->req->param('kingdom_id') ) {
        $kingdom = $kingdoms[0];
    }
    else {
        $kingdom = $c->model('DBIC::Kingdom')->find(
            {
                kingdom_id => $c->req->param('kingdom_id'),
            }
        );
    }

    my @messages = $kingdom->search_related(
        'messages',
        {
            'type' => 'board',
        },
        {
            prefetch => 'day',
            order_by => [ 'day.day_id desc', 'message_id desc' ],
        }
    );

    my $bbc = HTML::BBCode->new( {
            allowed_tags => [qw/b u i quote list url/],
            stripscripts => 1,
            linebreaks   => 1,
    } );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/kingdom_boards/view.html',
                params   => {
                    kingdom       => $kingdom,
                    messages      => \@messages,
                    bbc           => $bbc,
                    more_messages => 0,
                    kingdoms      => \@kingdoms,
                },
            }
        ]
    );

}

1;
