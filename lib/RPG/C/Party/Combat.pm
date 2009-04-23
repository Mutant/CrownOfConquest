package RPG::C::Party::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub attack : Local {
    my ( $self, $c ) = @_;

    # TODO: validate party being attacked

    my $battle = $c->model('Party_Battle')->create( {} );

    $battle->add_to_participants( { party_id => $c->stash->{party}->id, } );

    $battle->add_to_participants( { party_id => $c->req->param('party_id'), } );

    $c->forward('/panel/refresh');
}

sub main : Private {
    my ( $self, $c ) = @_;

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'combat/main.html',
                params        => { opposing_party => $c->stash->{party}->in_party_battle_with, },
                return_output => 1,
            },
        ]
    );
}

sub fight : Local {
    my($self, $c) = @_;
}

1;
