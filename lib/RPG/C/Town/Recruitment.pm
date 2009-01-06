package RPG::C::Town::Recruitment;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

use Carp;

sub default : Path {
    my ( $self, $c ) = @_;
    
    my $town = $c->stash->{party_location}->town;
    
    my @characters = $town->characters;
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/recruitment/main.html',
                params => {
                    characters => \@characters,
                    party => $c->stash->{party},
                },
            }
        ]
    );
}

sub buy : Local {
    my ( $self, $c ) = @_;
    
    my $character = $c->model('DBIC::Character')->find($c->req->param('character_id'));
    
    if ($character->town_id != $c->stash->{party_location}->town->id) {
        croak "Invalid character id: " . $c->req->param('character_id');
    }
    
    if ($c->stash->{party}->gold < $character->value) {
        croak "Can't afford that character\n";
    }
    
    $c->stash->{party}->gold($c->stash->{party}->gold - $character->value);
    $c->stash->{party}->update;
    
    $character->party_id($c->stash->{party}->id);
    $character->town_id(undef);
    $character->party_order(scalar $c->stash->{party}->characters + 1);
    $character->update;
    
    $c->res->redirect( $c->config->{url_root} . '/town/recruitment' ); 
}

1;
