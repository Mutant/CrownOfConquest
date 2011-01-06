package RPG::C::Town::Recruitment;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

use Carp;

sub default : Path {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @town_characters  = $town->characters;
    my @party_characters = $c->stash->{party}->members;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/recruitment/main.html',
                params   => {
                    town_characters      => \@town_characters,
                    party_characters     => \@party_characters,
                    party                => $c->stash->{party},
                    party_full           => $c->stash->{party}->is_full,
                    max_party_characters => $c->config->{max_party_characters},
                },
            }
        ]
    );
}

sub buy : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find( $c->req->param('character_id') );

    if ( $character->town_id != $c->stash->{party_location}->town->id ) {
        croak "Invalid character id: " . $c->req->param('character_id');
    }

    if ( $c->stash->{party}->gold < $character->value ) {
        croak "Can't afford that character\n";
    }

    if ( scalar $c->stash->{party}->members >= $c->config->{max_party_characters} ) {
        croak "Already enough characters in your party\n";
    }

    $c->stash->{party}->gold( $c->stash->{party}->gold - $character->value );
    $c->stash->{party}->update;

    $character->party_id( $c->stash->{party}->id );
    $character->town_id(undef);
    $character->party_order( scalar $c->stash->{party}->characters + 1 );
    $character->update;
    
    # Rejig party order
    $c->stash->{party}->adjust_order;

    $c->model('DBIC::Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $c->stash->{today}->id,
            event        => $character->character_name
                . " was recruited from the town "
                . $c->stash->{party_location}->town->town_name . " by "
                . $c->stash->{party}->name,
        },
    );

    $c->res->redirect( $c->config->{url_root} . '/town/recruitment' );
}

sub sell : Local {
    my ( $self, $c ) = @_;
    
    my $character = $c->model('DBIC::Character')->find( $c->req->param('character_id') );

    if ( $character->party_id != $c->stash->{party}->id ) {
        croak "Invalid character id: " . $c->req->param('character_id');
    }
    
    if ($character->is_dead) {
        croak "Can't sell a dead character\n";
    }   
    
    unless ($character->is_in_party) {
    	croak "Can't sell a character not in party\n";	
    }

    my @party_characters = $c->stash->{party}->characters;
    if (scalar @party_characters <= 1) {
    	croak "Can't sell last character in the party";
    }

    $c->stash->{party}->gold( $c->stash->{party}->gold + $character->sell_value );
    $c->stash->{party}->update;

    $character->party_id(undef);
    $character->town_id( $c->stash->{party_location}->town->id );
    $character->party_order(undef);
    $character->update;
    
    # Rejig party order
    $c->stash->{party}->adjust_order;

    $c->model('DBIC::Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $c->stash->{today}->id,
            event        => $character->character_name
                . " was sold by "
                . $c->stash->{party}->name
                . " to the Recruitment markets of "
                . $c->stash->{party_location}->town->town_name,
        },
    );

    $c->res->redirect( $c->config->{url_root} . '/town/recruitment' );
}

1;
