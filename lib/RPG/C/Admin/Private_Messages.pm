package RPG::C::Admin::Private_Messages;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub view : Local {
    my ( $self, $c ) = @_;

    my $rs = $c->model('DBIC::Party_Messages')->search(
        {
            type => 'message',
        },
        {
            prefetch => 'recipients',
            order_by => \'day_id desc, me.message_id desc',
            page     => 1,
            rows     => 30,
        }
    );

    my $total_pages = $rs->pager->last_page;

    my $page = $c->req->param('page') // 1;

    my $bbc = HTML::BBCode->new( {
            allowed_tags => [qw/b u i quote list url/],
            stripscripts => 1,
            linebreaks   => 1,
    } );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/private_messages/view.html',
                params   => {
                    messages     => [ $rs->page($page)->all ],
                    current_page => $page,
                    total_pages  => $total_pages,
                    bbc          => $bbc,
                },
            }
        ]
    );
}

1;
