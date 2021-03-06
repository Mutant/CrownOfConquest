package RPG::C::Party::Create;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON;
use DateTime;
use List::Util qw(shuffle);
use Carp;
use HTML::Strip;

sub auto : Private {
    my ( $self, $c ) = @_;

    return 1 if $c->req->action eq 'party/create/calculate_values';

    unless ( $c->stash->{party} ) {
        $c->stash->{party} = $c->model('DBIC::Party')->find_or_create(
            {
                player_id => $c->session->{player}->id,
                defunct   => undef,
            },
        );
    }

    if ( $c->stash->{party}->created ) {
        die "Shouldn't be creating a party when you already have one!\n";
    }

    return 1;
}

sub create : Local {
    my ( $self, $c ) = @_;

    my $party = $c->stash->{party};

    my @characters = $party->characters;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/create.html',
                params   => {
                    player     => $c->session->{player},
                    party      => $party,
                    characters => \@characters,
                    num_characters_to_create => $c->config->{new_party_characters},
                    message => $c->flash->{promo_org_message},
                },
            }
        ]
    );
}

sub save_party : Local {
    my ( $self, $c ) = @_;

    my $hs = HTML::Strip->new();

    if ( $c->req->param('add_character') ) {
        $c->stash->{party}->update;
        $c->res->redirect( $c->config->{url_root} . '/party/create/new_character' );
        return;
    }

    my $name = $hs->parse( $c->req->param('name') );

    unless ($name) {
        $c->stash->{error} = "You must enter a party name!";
        $c->detach('create');
    }

    # Check there's not already a party with this name
    my $dupe_party = $c->model('DBIC::Party')->find(
        {
            name    => $name,
            defunct => undef,
        },
    );

    if ( $dupe_party && $dupe_party->id != $c->stash->{party}->id ) {
        $c->stash->{error} = "A party with that name already exists. Please choose another one";
        $c->detach('create');
    }

    $c->stash->{party}->name($name);

    if ( $c->stash->{party}->characters->count < $c->config->{new_party_characters} ) {
        $c->stash->{error} = "You still have more character's to create!";
        $c->detach('create');
    }

    my $start_turns = $c->config->{starting_turns};
    my $code        = $c->model('DBIC::Promo_Code')->find(
        {
            'player.player_id' => $c->session->{player}->id,
        },
        {
            'prefetch' => 'promo_org',
            'join'     => 'player',
            'for'      => 'update',
        },
    );

    if ($code) {
        $start_turns += $code->promo_org->extra_start_turns;
        $code->decrement_uses_remaining;
        $code->update;
    }

    $c->stash->{party}->_turns($start_turns);
    $c->stash->{party}->gold( $c->config->{start_gold} );
    $c->stash->{party}->created( DateTime->now() );

    foreach my $character ( $c->stash->{party}->characters ) {
        $character->roll_all;

        $character->create_item_grid;

        $character->set_default_spells;

        $character->set_starting_equipment;

        $c->model('DBIC::Character_History')->create(
            {
                character_id => $character->id,
                day_id       => $c->stash->{today}->id,
                event        => $character->character_name
                  . " joined "
                  . $c->stash->{party}->name
                  . " as a fresh-faced level 1 "
                  . $character->class->class_name,
            },
        );
    }

    # Find starting town
    my @towns = shuffle $c->model('DBIC::Town')->search(
        {
            prosperity => {
                '<=', $c->config->{max_starting_prosperity},
                '>=', $c->config->{min_starting_prosperity},
            },
        }
    );

    my $town = shift @towns;
    $c->stash->{party}->land_id( $town->land_id );

    $c->stash->{party}->update;

    # Create Watcher effect
    my $effect = $c->model('DBIC::Effect')->create(
        {
            effect_name => 'Watcher',
            time_left   => $c->config->{new_party_watcher_days},
            time_type   => 'day',
            combat      => 0,
        },
    );

    $c->model('DBIC::Party_Effect')->create(
        {
            party_id  => $c->stash->{party}->id,
            effect_id => $effect->id,
        }
    );

    $c->flash->{created_message} = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/complete.html',
                params   => {
                    party => $c->stash->{party},
                    town  => $c->stash->{party}->location->town,
                },
                return_output => 1,
            }
        ]
    );


    $c->res->redirect( $c->config->{url_root} );
}

sub new_character : Local {
    my ( $self, $c ) = @_;

    if ( $c->config->{new_party_characters} <= $c->model('DBIC::Character')->count( { party_id => $c->stash->{party}->id } ) ) {
        $c->forward(
            'RPG::V::TT',
            [
                {
                    template => 'party/max_characters.html',
                    params => { max_allowed => $c->config->{new_party_characters} },
                }
            ]
        );
    }
    else {
        $c->forward('new_character_form');
    }
}

sub edit_character : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find( { character_id => $c->req->param('character_id'), }, { prefetch => [ 'race', 'class' ] } );

    croak "Invalid character" unless $character && $character->party_id == $c->stash->{party}->id;

    my %params = (
        name         => $character->character_name,
        race         => $character->race_id,
        class        => $character->class->class_name,
        mod_str      => $character->strength - $character->race->base_str,
        mod_agl      => $character->agility - $character->race->base_agl,
        mod_int      => $character->intelligence - $character->race->base_int,
        mod_div      => $character->divinity - $character->race->base_div,
        mod_con      => $character->constitution - $character->race->base_con,
        character_id => $character->id,
        gender       => $character->gender,
    );

    $c->forward( 'new_character_form', [ \%params ] );

}

sub new_character_form : Private {
    my ( $self, $c, $params ) = @_;

    $params ||= {};

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/new_character.html',
                params   => {
                    races      => [ $c->model('DBIC::Race')->all ],
                    classes    => [ $c->model('DBIC::Class')->all ],
                    stats_pool => $c->config->{stats_pool},
                    stat_max   => $c->config->{stat_max},
                    action     => '/party/create/create_character',
                    %$params,
                },
                fill_in_form => 1,
            }
        ]
    );
}

sub create_new_character : Private {
    my ( $self, $c ) = @_;

    my $hs = HTML::Strip->new();

    my $name = $hs->parse( $c->req->param('name') );

    unless ( $name && $c->req->param('race') && $c->req->param('class') ) {
        $c->stash->{error} = 'Please choose a name, race and class';
        return;
    }

    unless ( $c->req->param('gender') eq 'male' || $c->req->param('gender') eq 'female' ) {
        $c->stash->{error} = 'Please choose a gender';
        return;
    }

    my $total_mod_points = 0;
    foreach my $stat (@RPG::Schema::Character::STATS) {
        my $mod_points = $c->req->param( 'mod_' . $stat ) || 0;

        if ( $mod_points < 0 ) {
            $c->stash->{error} = "You've set a modifier to a negative value! Modifiers must be positive or zero";
            return;
        }

        $total_mod_points += $mod_points;
    }

    if ( $total_mod_points > $c->config->{stats_pool} ) {
        $c->stash->{error} = "You've used more than the total stats pool!";
        return;
    }

    my $race = $c->model('DBIC::Race')->find( $c->req->param('race') );

    my $class = $c->model('DBIC::Class')->find( { class_name => $c->req->param('class') } );

    my %char_params = (
        character_name => $name,
        class_id       => $class->id,
        race_id        => $c->req->param('race'),
        strength       => $race->base_str + int $c->req->param('mod_str') || 0,
        intelligence   => $race->base_int + int $c->req->param('mod_int') || 0,
        agility        => $race->base_agl + int $c->req->param('mod_agl') || 0,
        divinity       => $race->base_div + int $c->req->param('mod_div') || 0,
        constitution   => $race->base_con + int $c->req->param('mod_con') || 0,
        party_id       => $c->stash->{party}->id,
        gender         => $c->req->param('gender'),
        level          => 1,
    );

    my $character;

    if ( $c->req->param('character_id') ) {
        $character = $c->model('DBIC::Character')->find( { character_id => $c->req->param('character_id'), } );

        croak "Invalid character" unless $character->party_id == $c->stash->{party}->id;

        while ( my ( $field, $value ) = each %char_params ) {
            $character->set_column( $field, $value );
        }
        $character->update;
    }
    else {
        my $max_order_rec = $c->model('DBIC::Character')->find(
            {
                party_id => $c->stash->{party}->id,
            },
            {
                select => { max => 'party_order' },
                as => 'order',
            }
        );
        my $max_order = $max_order_rec->get_column('order') // 0;

        $character = $c->model('DBIC::Character')->create( { %char_params, party_order => $max_order + 1, }, );

    }

    return $character;
}

sub create_character : Local {
    my ( $self, $c ) = @_;

    my $char_count = $c->model('DBIC::Character')->count( { party_id => $c->stash->{party}->id } );
    if ( !$c->req->param('character_id') && $char_count >= $c->config->{new_party_characters} ) {
        croak 'You already have ' . $c->config->{new_party_characters} . ' characters in your party';
    }

    $c->forward('create_new_character');

    if ( $c->stash->{error} ) {
        $c->detach('new_character_form');
    }

    $c->res->redirect( $c->config->{url_root} . '/party/create' );
}

sub delete_character : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find( { character_id => $c->req->param('character_id'), }, { prefetch => [ 'race', 'class' ] } );

    croak "Invalid character" unless $character && $character->party_id == $c->stash->{party}->id;

    $character->delete;

    $c->res->redirect( $c->config->{url_root} . '/party/create' );
}

=head2 calculate_values

Calculate hit point, magic point, and faith points (where appropriate) for a particular class

=cut

sub calculate_values : Local {
    my ( $self, $c ) = @_;

    my $return;

    unless ( $c->req->param('class') && $c->req->param('total_con') && $c->req->param('total_int') && $c->req->param('total_div') ) {
        $return = to_json {};
    }
    else {
        my $class = $c->model('DBIC::Class')->find( { class_name => $c->req->param('class') } );

        my %points = ( hit_points => RPG::Schema::Character->roll_hit_points( $c->req->param('class'), 1, $c->req->param('total_con') ) );

        $points{magic_points} = RPG::Schema::Character->roll_spell_points( 1, $c->req->param('total_int') )
          if $class->class_name eq 'Mage';

        $points{faith_points} = RPG::Schema::Character->roll_spell_points( 1, $c->req->param('total_div') )
          if $class->class_name eq 'Priest';

        $return = to_json( \%points );

    }

    $c->res->body($return);
}

sub autogenerate : Local {
    my ( $self, $c ) = @_;

    # Delete any characters that already exist
    $c->stash->{party}->characters->delete;

    my @CLASSES_TO_CREATE = qw(Warrior Warrior Archer Priest Mage);

    my $order = 1;
    foreach my $class_name (@CLASSES_TO_CREATE) {
        my $class = $c->model('DBIC::Class')->find( { 'class_name' => $class_name } );
        my $race = $c->model('DBIC::Race')->random;

        my $character = $c->model('DBIC::Character')->generate_character(
            race        => $race,
            class       => $class,
            level       => 1,
            roll_points => 0,
            stat_weight => 8,
        );
        $character->party_id( $c->stash->{party}->id );
        $character->party_order($order);
        $character->update;

        $order++;
    }

    $c->res->redirect( $c->config->{url_root} . '/party/create/create' );
}

1;
