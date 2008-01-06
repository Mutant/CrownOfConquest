package RPG::C::Character;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;

sub view : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('Character')->find({ 
        character_id => $c->req->param('character_id'),
        party_id => $c->session->{party_id},
    });
    
    $c->forward('RPG::V::TT',
        [{
            template => 'character/view.html',
            params => {
                character => $character,
            }
        }]
    );
}

sub item_list : Local {
    my ($self, $c) = @_;
    
    my $character = $c->model('Character')->find({ 
        character_id => $c->req->param('character_id'),
        party_id => $c->session->{party_id},
    });
    
    my @items = $character->items;
    
    my @items_to_return;
    foreach my $item (@items) {
        push @items_to_return, {
            item_type => $item->item_type->item_type,
            item_id => $item->id,
        };
    }
    
    my $ret = jsdump(characterItems => \@items_to_return);
    
    $c->res->body($ret);    
}

1;