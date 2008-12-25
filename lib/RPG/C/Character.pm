package RPG::C::Character;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

use Carp;

sub view : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        },
        { prefetch => [ 'race', 'class', ], },
    );

    my $next_level = $c->model('DBIC::Levels')->find( { level_number => $character->level + 1, } );

    my @characters = $c->stash->{party}->characters;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/view.html',
                params   => {
                    character         => $character,
                    characters        => \@characters,
                    xp_for_next_level => $next_level->xp_needed,
                    selected          => $c->stash->{selected_tab},
                }
            }
        ]
    );
}

sub equipment_tab : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            party_id     => $c->stash->{party}->id,
            character_id => $c->req->param('character_id'),
        }
    );

    croak "Invalid character id" unless $character;

    my @items = $c->model('DBIC::Items')->search(
        { character_id => $c->req->param('character_id'), },
        {
            prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
            order_by => 'item_category',
        },
    );

    my $equipped_items = $character->equipped_items(@items);

    my %equip_place_category_list = $c->model('DBIC::Equip_Places')->equip_place_category_list;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/equipment_tab.html',
                params   => {
                    character                 => $character,
                    equipped_items            => $equipped_items,
                    equip_place_category_list => \%equip_place_category_list,
                    items                     => \@items,
                }
            }
        ]
    );
}

sub item_list : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        }
    );

    my @items = $character->items;

    my @items_to_return;
    foreach my $item (@items) {
        push @items_to_return,
            {
            item_type => $item->item_type->item_type,
            item_id   => $item->id,
            };
    }

    my $ret = jsdump( characterItems => \@items_to_return );

    $c->res->body($ret);
}

sub equip_item : Local {
    my ( $self, $c ) = @_;

    my $item =
        $c->model('DBIC::Items')
        ->find( { item_id => $c->req->param('item_id'), }, { prefetch => { 'item_type' => { 'item_attributes' => 'item_attribute_name' } }, }, );

    # Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    if ( scalar( grep { $_->id eq $item->character_id } @characters ) == 0 ) {
        $c->log->warn( "Attempted to equip item "
                . $item->id
                . " by party "
                . $c->stash->{party}->id
                . ", but item does not belong to this party (item is owned by character: "
                . $item->character_id
                . ")" );
        return;
    }

    my @slots_changed;
    eval { @slots_changed = $item->equip_item( $c->req->param('equip_place') ); };
    if ($@) {

        # TODO: need better way of detecting exceptions
        if ( $@ =~ "Can't equip an item of that type there" ) {
            $c->res->body( to_json( { error => "You can't equip a " . $item->item_type->item_type . " there!" } ) );
            return;
        }
        else {

            # Rethrow
            croak $@;
        }
    }

    my %ret;
    if ( scalar @slots_changed > 1 ) {

        # More than one slot changed... clear anything that wasn't the slot we tried to equip to
        # XXX: currently the AJAX call just expects one slot to clear, since there's no way more than one
        #  could be cleared. If this changes, we'll have to give it a different data structure
        my @slots_to_clear = grep { $_ ne $c->req->param('equip_place') } @slots_changed;

        # Just warn for now if we have more than 1
        $c->log->warn("Found more than one slot to clear in equip_item") if scalar @slots_to_clear > 1;

        %ret = ( clear_equip_place => $slots_to_clear[0] );
    }

    $c->res->body( to_json( \%ret ) );
}

sub give_item : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        },
    );

    # Make sure character being given to is in the party
    unless ($character) {
        $c->log->warn( "Can't find " . $c->req->param('character_id') . " in party " . $c->stash->{party}->id );
        return;
    }

    my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), } );

    # Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    if ( scalar( grep { $_->id eq $item->character_id } @characters ) == 0 ) {
        $c->log->warn( "Attempted to give item  "
                . $item->id
                . " within party "
                . $c->stash->{party}->id
                . ", but item does not belong to this party (item is owned by character: "
                . $item->character_id
                . ")" );
        return;
    }

    my $slot_to_clear = $item->equip_place_id ? $item->equipped_in->equip_place_name : undef;

    $item->equip_place_id(undef);
    $item->add_to_characters_inventory($character);
    $item->update;

    $c->res->body(
        to_json(
            {
                message           => "A " . $item->item_type->item_type . " was given to " . $character->character_name,
                clear_equip_place => $slot_to_clear,

            }
        )
    );
}

# Called by shop screen to get list of equipment.
sub equipment_list : Local {
    my ( $self, $c ) = @_;

    my ($character) = grep { $_->id eq $c->req->param('character_id') } $c->stash->{party}->characters;

    # Make sure character is in the party
    unless ($character) {
        $c->log->warn( "Can't find " . $c->req->param('character_id') . " in party " . $c->stash->{party}->id );
        return;
    }

    my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id'), } );

    my @items = $c->model('DBIC::Items')->search(
        { character_id => $character->id, },
        {
            prefetch => [ 'item_type', 'item_variables' ],
            order_by => 'item_type.item_type',
        }
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/equipment_list.html',
                params   => {
                    items => \@items,
                    shop  => $shop,
                }
            }
        ]
    );

}

sub spells_tab : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        },
    );

    return unless $character;

    my @memorised_spells =
        $c->model('DBIC::Memorised_Spells')->search( { character_id => $c->req->param('character_id'), }, { prefetch => 'spell', }, );

    my @available_spells = $c->model('DBIC::Spell')->search(
        {
            class_id => $character->class_id,
            hidden   => 0,
        },
        { order_by => 'spell_name', },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/spells_tab.html',
                params   => {
                    character        => $character,
                    memorised_spells => \@memorised_spells,
                    available_spells => \@available_spells,
                }
            }
        ]
    );
}

sub memorise_spell : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        },
    );

    return unless $character;

    my $spell = $c->model('DBIC::Spell')->find( { spell_id => $c->req->param('spell_id'), }, );

    return unless $spell;

    if ( $spell->points * $c->req->param('number') > $character->spell_points - $character->spell_points_used( $spell->id ) ) {
        $c->stash->{error} = $character->character_name . " doesn't have enough spell points to memorise " . $spell->spell_name;
    }
    else {
        my $memorised_spell = $c->model('DBIC::Memorised_Spells')->find_or_create(
            {
                character_id => $character->id,
                spell_id     => $spell->id,
            },
        );

        $memorised_spell->memorise_tomorrow(1);
        $memorised_spell->memorise_count_tomorrow( $c->req->param('number') );
        $memorised_spell->update;
    }

    $c->stash->{selected_tab} = 'spells';
    $c->forward('/character/view');
}

sub unmemorise_spell : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        },
    );

    return unless $character;

    my $spell = $c->model('DBIC::Spell')->find( { spell_id => $c->req->param('spell_id'), }, );

    return unless $spell;

    my $memorised_spell = $c->model('DBIC::Memorised_Spells')->find(
        {
            character_id => $character->id,
            spell_id     => $spell->id,
        },
    );

    $memorised_spell->memorise_count_tomorrow( $memorised_spell->memorise_count_tomorrow - 1 )
        if $memorised_spell->memorise_count_tomorrow != 0;
    $memorised_spell->memorise_tomorrow(0)
        if $memorised_spell->memorise_count_tomorrow == 0;
    $memorised_spell->update;

    $c->stash->{selected_tab} = 'spells';
    $c->forward('/character/view');
}

sub add_stat_point : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            character_id => $c->req->param('character_id'),
            party_id     => $c->stash->{party}->id,
        },
    );

    unless ( $character->stat_points != 0 ) {
        $c->res->body( to_json( { error => 'No stat points to add' } ) );
        return;
    }

    if ( my $stat = $character->get_column( $c->req->param('stat') ) ) {
        $character->set_column( $c->req->param('stat'), $stat + 1 );
        $character->stat_points( $character->stat_points - 1 );
        $character->update;
    }

    # Need to return something so caller knows it was successful
    $c->res->body( to_json( {} ) );
}

sub history_tab : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            party_id     => $c->stash->{party}->id,
            character_id => $c->req->param('character_id'),
        }
    );

    croak "Invalid character id" unless $character;

    my @history = $c->model('DBIC::Character_History')->search(
        { character_id => $c->req->param('character_id'), },
        {
            prefetch => 'day',
            order_by => [ 'day.day_number desc', 'history_id desc' ],
        },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/history_tab.html',
                params   => { history => \@history, }
            }
        ]
    );
}

1;
