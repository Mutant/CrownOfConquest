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
                    train_min_party_level => $c->config->{train_min_party_level},
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

    $c->forward( '/panel/refresh', [[screen => '/town/recruitment'], 'party_status', 'party'] );
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

    if (Games::Dice::Advanced->roll('1d100') <= $c->config->{character_sell_deletion_chance}) {
        $character->delete;   
    }
    else {
        $character->status('recruitment_hold');
        $character->status_context($c->stash->{party_location}->town->id);
        $character->party_id(undef);
        $character->party_order(undef);
        $character->update;

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
    }
        
    $c->forward( '/panel/refresh', [[screen => '/town/recruitment'], 'party_status', 'party'] );
}

sub train : Local {
    my ($self, $c) = @_;
    
    my $message = "Training a new character costs " . $c->config->{train_turn_cost} . " turns and " . $c->config->{train_gold_cost} . " gold";
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/new_character.html',
                params => {
                    in_screen => 1,
                    title => 'Train Character',
                    races      => [ $c->model('DBIC::Race')->all ],
                    classes    => [ $c->model('DBIC::Class')->all ],
                    stats_pool => $c->config->{stats_pool},
                    stat_max   => $c->config->{stat_max},
                    action     => '/town/recruitment/create_trained',
                    new_char_message => $message,                     
                },
                fill_in_form => 1,
            }
        ],
    );
}

sub create_trained : Local {
    my ($self, $c) = @_;
    
    croak "Party not in a town" unless $c->stash->{party_location}->town;

    croak "Party not high enough level to train" if $c->stash->{party} < $c->config->{train_min_party_level};
    
    croak "Party is full and cannot train a new character" if $c->stash->{party}->is_full;
    
    croak "Can't train existing character" if $c->req->param('character_id');
    
    if ($c->stash->{party}->turns < $c->config->{train_turn_cost}) {
        $c->stash->{error} = $c->forward('/party/not_enough_turns',['train a new character']);
        $c->forward( '/panel/refresh', [[screen => '/town/recruitment']] );
        return;
    }
    
    if ($c->stash->{party}->gold < $c->config->{train_gold_cost}) {
        $c->stash->{error} = "You do not have enough gold to train a new character";
        $c->forward( '/panel/refresh', [[screen => '/town/recruitment']] );
        return;
    }
    
    my $character = $c->forward('/party/create/create_new_character');
    
    if ($c->stash->{error}) {
        $c->forward( '/panel/refresh', [[screen => '/town/recruitment/train']] );
        return;
    }

    $character->roll_all;
    $character->create_item_grid;
    $character->set_default_spells;
    $character->set_starting_equipment;

    $c->model('DBIC::Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $c->stash->{today}->id,
            event        => $character->character_name
                . " was trained as a level 1 " . $character->class->class_name 
                . " in the town of " . $c->stash->{party_location}->town->town_name 
                . " by the party "
                . $c->stash->{party}->name,
        },
    );
    
    $c->stash->{party}->turns($c->stash->{party}->turns - $c->config->{train_turn_cost});
    $c->stash->{party}->gold($c->stash->{party}->gold - $c->config->{train_gold_cost});
    $c->stash->{party}->update;
    
    $c->stash->{panel_messages} = "New character trained";
       
    $c->forward( '/panel/refresh', [[screen => '/town/recruitment'], 'party_status', 'party'] );

}

1;
