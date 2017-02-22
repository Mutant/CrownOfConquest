package RPG::C::KingdomBoard;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use HTML::BBCode;

sub auto : Private {
    my ( $self, $c ) = @_;

    my $kingdom = $c->stash->{party}->kingdom;

    croak "No kingdom\n" unless $kingdom;

    $c->stash->{kingdom} = $kingdom;

    return 1;
}

sub view : Local {
    my ( $self, $c ) = @_;

    my $rows_per_page = 10;

    my @messages = reverse $c->stash->{kingdom}->search_related(
        'messages',
        {
            'type' => 'board',
        },
        {
            prefetch => 'day',
            order_by => [ 'day.day_id desc', 'message_id desc' ],
            rows     => $rows_per_page,
            offset   => $c->req->param('older') * $rows_per_page,
        }
    );

    my $message_count = $c->stash->{kingdom}->search_related(
        'messages',
        {
            'type' => 'board',
        },
    )->count;

    my $older_count = ( $c->req->param('older') // 0 ) + 1;
    my $more_messages = $message_count - 1 > $rows_per_page * $older_count ? 1 : 0;

    my $bbc = HTML::BBCode->new( {
            allowed_tags => [qw/b u i quote list url/],
            stripscripts => 1,
            linebreaks   => 1,
    } );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'kingdom/board/main.html',
                params   => {
                    kingdom       => $c->stash->{kingdom},
                    messages      => \@messages,
                    bbc           => $bbc,
                    more_messages => $more_messages,
                    older_count   => $older_count,
                },
            }
        ]
    );
}

sub post : Local {
    my ( $self, $c ) = @_;

    $c->stash->{kingdom}->add_to_messages(
        {
            'type'     => 'board',
            'message'  => $c->req->param('message'),
            'day_id'   => $c->stash->{today}->id,
            'party_id' => $c->stash->{party}->id,
        }
    );

    $c->forward( '/panel/refresh', [ [ screen => 'kingdomboard/view' ] ] );

}

1;
