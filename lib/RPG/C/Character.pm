package RPG::C::Character;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

use Carp;

sub auto : Private {
    my ( $self, $c ) = @_;
    
    return 1 unless $c->req->param('character_id');

    $c->stash->{character} =
        $c->model('DBIC::Character')->find( { character_id => $c->req->param('character_id'), }, { prefetch => [ 'race', 'class', ], }, );

	confess "Character not found! ID: " . $c->req->param('character_id') unless $c->stash->{character};

    # Make sure party is allowed to view this character
    if ( $c->stash->{character}->party_id && $c->stash->{character}->party_id != $c->stash->{party}->id ) {
        croak "Not allowed to view this character\n";
    }
    elsif ( $c->stash->{character}->town_id && $c->stash->{character}->town_id != $c->stash->{party_location}->town->id ) {
        croak "Not allowed to view this character\n";
    }

    return 1;
}

sub view : Local {
    my ( $self, $c ) = @_;

    my $character = $c->stash->{character};

    my $next_level = $c->model('DBIC::Levels')->find( { level_number => $character->level + 1, } );

    my @characters;
    if ( $character->party_id ) {
        @characters = $c->stash->{party}->characters;
    }
    else {
        @characters = $c->stash->{party_location}->town->characters;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/view.html',
                params   => {
                    character         => $character,
                    characters        => \@characters,
                    xp_for_next_level => $next_level ? $next_level->xp_needed : '????',
                    selected          => $c->stash->{selected_tab} || $c->req->param('selected'),
                    item_mode         => $c->req->param('item_mode') || '',
                }
            }
        ]
    );
}

sub equipment_tab : Local {
    my ( $self, $c ) = @_;

    my $character = $c->stash->{character};

    croak "Invalid character id" unless $character;
    
    my $item_mode = $c->req->param('item_mode') || 'char';
    
    my $criteria;
    my @extra_join;

    if ($item_mode eq 'char') {
    	$criteria = { character_id => $c->req->param('character_id'), };
    }
    else {
    	$criteria = { 'belongs_to_character.party_id' => $c->stash->{party}->id, };
    	@extra_join = ('belongs_to_character');
    }

    my @items = $c->model('DBIC::Items')->search(
        $criteria,
        {
            prefetch => [
            	{ 'item_variables' => 'item_variable_name' },
            	{'item_type' => [
            		'category',
            		{ 'item_attributes' => 'item_attribute_name' },            		
            	]},
            ],
            join => [ @extra_join ],
            order_by => 'item_category',
        },
    );

	# Get list of items this char has, to allow us to build the equipped_items hash
	my @characters_items = grep { $_->character_id == $character->id } @items;

    my $equipped_items = $character->equipped_items(@characters_items);
    
    my %equipped_items_by_id = 
    	map { $equipped_items->{$_} ? ($equipped_items->{$_}->id => $equipped_items->{$_}) : () } keys %$equipped_items; 

    my %equip_place_category_list = $c->model('DBIC::Equip_Places')->equip_place_category_list;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/equipment_tab.html',
                params   => {
                    character                 => $character,
                    equipped_items            => $equipped_items,
                    equipped_items_by_id      => \%equipped_items_by_id,
                    equip_place_category_list => \%equip_place_category_list,
                    equip_places              => [ keys %equip_place_category_list ],
                    items                     => \@items,
                    item_mode                 => $item_mode,
                    party					  => $c->stash->{party},
                }
            }
        ]
    );
}

sub item_details : Local {
	my ($self, $c) = @_;
	
	my $item = $c->model('DBIC::Items')->find(
		{
			'item_id' => $c->req->param('item_id'),
		},
		{
			prefetch => [
				{ 'item_type' => 'category' },
				'item_variables',
			],
		}
	);
	
	# TODO: make sure item is in party's inventory
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/tooltip_specific.html',
                params   => {
					item => $item,
					item_type => $item->item_type,
                }
            }
        ]
    );	
	
}



sub item_list : Local {
    my ( $self, $c ) = @_;

    my $character = $c->stash->{character};

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
    my $equip_place = $c->req->param('equip_place');
    eval { @slots_changed = $item->equip_item( $equip_place ); };
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

    my %ret = (
    	$c->req->param('equip_place') => {
    		item_type => $item->item_type->item_type,
   			image => $item->item_type->image,
    	},
    );
    my $slots_cleared;
    if ( scalar @slots_changed > 1 ) {

        # More than one slot changed... clear anything that wasn't the slot we tried to equip to
        my @slots_to_clear = grep { $_ ne $c->req->param('equip_place') } @slots_changed;

        # Don't expect to get more than one slot changed (which might be a poor assumption)
        # Just warn for now if we have more than 1
        $c->log->warn("Found more than one slot to clear in equip_item") if scalar @slots_to_clear > 1;

        $ret{$slots_to_clear[0]} = {
        	item_type => undef,
   			image => undef,
        };
    }
        
    $c->res->body( to_json( {changed_slots => \%ret} ) );
}

sub give_item : Local {
    my ( $self, $c ) = @_;

    $c->forward('check_action_allowed');

    my $character = $c->stash->{character};

    my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), } );

    my @characters = $c->stash->{party}->characters;
	my ($original_character) = grep { $_->id eq $item->character_id } @characters;

    # Make sure this item belongs to a character in the party
    unless ( $original_character ) {
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
                clear_equip_place => $slot_to_clear,
                encumbrance       => $original_character->encumbrance,
            }
        )
    );
}

sub drop_item : Local {
    my ( $self, $c ) = @_;

    $c->forward('check_action_allowed');

    my $character = $c->stash->{character};

    my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), } );

    # Make sure this item belongs to a character in the party
    my @characters = $c->stash->{party}->characters;
    if ( scalar( grep { $_->id eq $item->character_id } @characters ) == 0 ) {
        $c->log->warn( "Attempted to drop item  "
                . $item->id
                . " within party "
                . $c->stash->{party}->id
                . ", but item does not belong to this party (item is owned by character: "
                . $item->character_id
                . ")" );
        return;
    }

    my $slot_to_clear = $item->equip_place_id ? $item->equipped_in->equip_place_name : undef;

    $item->delete;

    $c->res->body(
        to_json(
            {
                clear_equip_place => $slot_to_clear,
                encumbrance       => $character->encumbrance,
            }
        )
    );
}

# Called by shop screen to get list of equipment.
sub equipment_list : Local {
    my ( $self, $c ) = @_;

    my $character = $c->stash->{character};

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

    my $character = $c->stash->{character};

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

    my %memorised_spells_by_id = map { $_->spell->id => $_ } @memorised_spells;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'character/spells_tab.html',
                params   => {
                    character              => $character,
                    memorised_spells       => \@memorised_spells,
                    available_spells       => \@available_spells,
                    memorised_spells_by_id => \%memorised_spells_by_id,
                }
            }
        ]
    );
}

sub update_spells : Local {
    my ( $self, $c ) = @_;

    $c->forward('check_action_allowed');

    my $character = $c->stash->{character};

    my $params = $c->req->params;

    my @available_spells = $c->model('DBIC::Spell')->search(
        {
            class_id => $character->class_id,
            hidden   => 0,
        },
    );

    my %memorise_tomorrow;
    foreach my $param ( keys %$params ) {
        if ( $param =~ /^mem_tomorrow_(\d+)$/ ) {
            $memorise_tomorrow{$1} = $params->{$param};
        }
    }

    # Check they've got enough spell points
    my $points_to_memorise = 0;
    foreach my $spell_id ( keys %memorise_tomorrow ) {
        my ($spell) = grep { $_->id == $spell_id } @available_spells;
        croak "Couldn't find spell with id: $spell_id" unless $spell;
        $points_to_memorise += $spell->points * $memorise_tomorrow{$spell_id};
    }

    if ( $points_to_memorise > $character->spell_points ) {
        $c->stash->{error} = $character->character_name . " doesn't have enough spell points to memorise those spells";
    }
    else {
        foreach my $spell_id ( keys %memorise_tomorrow ) {
            my $memorised_spell = $c->model('DBIC::Memorised_Spells')->find_or_create(
                {
                    character_id => $character->id,
                    spell_id     => $spell_id,
                },
            );

            my $mem_count = $memorise_tomorrow{$spell_id};
            if ( $mem_count > 0 ) {
                $memorised_spell->memorise_tomorrow(1);
            }
            else {
                $memorised_spell->memorise_tomorrow(0);
            }

            $memorised_spell->memorise_count_tomorrow($mem_count);
            $memorised_spell->update;
        }
    }

    $c->stash->{selected_tab} = 'spells';
    $c->forward('/character/view');

}

sub add_stat_point : Local {
    my ( $self, $c ) = @_;

    $c->forward('check_action_allowed');

    my $character = $c->stash->{character};

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

    my $character = $c->stash->{character};

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

sub change_name : Local {
    my ( $self, $c ) = @_;

    $c->forward('check_action_allowed');

    my $character = $c->stash->{character};

    my $original_name = $character->character_name;

    $character->character_name( $c->req->param('new_name') );
    $character->update;

    $c->model('DBIC::Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $c->stash->{today}->id,
            event        => $original_name . " is now known as " . $c->req->param('new_name'),
        },
    );

    $c->res->body( to_json {} );
}

sub bury : Local {
    my ( $self, $c ) = @_;

    $c->forward('check_action_allowed');

    my $character = $c->stash->{character};

    $c->model('DBIC::Grave')->create(
        {
            character_name => $character->character_name,
            land_id        => $c->stash->{party_location}->id,
            day_created    => $c->stash->{today}->day_number,
            epitaph        => $c->req->param('epitaph'),
        }
    );

    $c->stash->{messages} = "You say your last goodbyes to " . $character->character_name . ". R.I.P.";

    $character->delete;
    
    $c->stash->{party}->adjust_order;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status', 'party' ] );

}

sub check_action_allowed : Local {
    my ( $self, $c ) = @_;

    unless ( $c->stash->{character}->party_id ) {
        croak "Can only make changes to a character in your party\n";
    }
}

1;
