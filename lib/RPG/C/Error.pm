package RPG::C::Error;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub js_log : Local {
    my ($self, $c) = @_;
    
    $c->log->error('An javascript error occured...');    
    $c->log->error( "Params: " . Dumper $c->req->params );
    $c->log->error( "Player: " . $c->session->{player}->id ) if $c->session->{player};
    $c->log->error( "Party: " . $c->stash->{party}->id )     if $c->stash->{party};       
}

1;