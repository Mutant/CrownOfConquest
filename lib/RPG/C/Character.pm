package RPG::C::Character;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use HTML::Strip;

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
	if ( ! $c->stash->{character}->party_id && $c->stash->{character}->town_id != $c->stash->{party_location}->town->id ) {
		croak "Not allowed to view this character\n";
	}

	return 1;
}

sub view : Local {
	my ( $self, $c ) = @_;

	my $character = $c->stash->{character};

    my %chars_by_type;
    my @characters;
    my $group;
 	if ( $character->party_id ) {
        ($group, %chars_by_type) = $self->gen_character_list($c, $character);
    	
 	}
 	else {
		@characters = $c->stash->{party_location}->town->characters;
 	}
	my $can_buy = 0;
	if ($character->town_id && $c->stash->{party}->gold >= $character->value && ! $c->stash->{party}->is_full) {
        $can_buy = 1; 	          
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'character/view.html',
				params   => {
					character           => $character,
					character_list      => %chars_by_type ? \%chars_by_type : \@characters,
					selected            => $c->stash->{selected_tab} || $c->req->param('selected') || '',
					item_mode => $c->req->param('item_mode') || '',
					can_buy => $can_buy,
					group => $group,
					window => $c->req->param('window') || '',
				}
			}
		]
	);
}

# Generate a data structure with the party's characters for the 'jump to' menu 
sub gen_character_list {
    my ( $self, $c, $character ) = @_;
    
    my %chars_by_type;
    my $group = 'others';
    
    my @characters = $c->model('DBIC::Character')->search(
        {
            party_id => $c->stash->{party}->id,
        }
    );
    
    foreach my $other_char (@characters) {
        if ($other_char->garrison_id && $character->garrison_id == $other_char->garrison_id) {
            push @{ $chars_by_type{group} }, {
                name => $other_char->name,
                id => $other_char->id,
            };
            $group = 'group';
        }
        elsif ($other_char->mayor_of && $other_char->mayor_of == $character->mayor_of || 
            $other_char->mayor_of && $character->status eq 'mayor_garrison' && $character->status_context == $other_char->mayor_of ||
            $character->mayor_of && $other_char->status eq 'mayor_garrison' && $other_char->status_context == $character->mayor_of ||
            $character->status && $character->status eq 'mayor_garrison' && $other_char->status eq 'mayor_garrison' && $other_char->status_context == $character->status_context) {
                
            push @{ $chars_by_type{group} }, {
                name => $other_char->name,
                id => $other_char->id,
            };
            $group = 'group';
        }
        elsif (grep { $_->id == $other_char->id } $c->stash->{party}->characters) {
            push @{ $chars_by_type{party} }, {
                name => $other_char->name,
                id => $other_char->id,
            };            
        }
        else {
            push @{ $chars_by_type{others} }, {
                name => $other_char->name,
                id => $other_char->id,
            };
        }
    }
    
 	if (! $character->status && $group ne 'group') {
        $group = 'party';
	}
		
	return ($group, %chars_by_type);    
}

sub stats : Local {
	my ( $self, $c ) = @_;

	my $character = $c->stash->{character};

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'character/stats.html',
				params   => {
					character => $character,
				}
			}
		]
	);
}

sub equipment_tab : Local {
	my ( $self, $c ) = @_;

	my $character = $c->stash->{character};

	croak "Invalid character id" unless $character;

	my $equipped_items = $character->equipped_items();

	my %equipped_items_by_id =
		map { $equipped_items->{$_} ? ( $equipped_items->{$_}->id => $equipped_items->{$_} ) : () } keys %$equipped_items;

	my %equip_place_category_list = $c->model('DBIC::Equip_Places')->equip_place_category_list;
	
	my @allowed_to_give_to_characters;
	if (! $character->garrison_id || $c->stash->{party_location}->land_id == $character->garrison->land_id) {
	   @allowed_to_give_to_characters = $c->stash->{party}->characters_in_sector;
	}
	else {
	    @allowed_to_give_to_characters = $character->garrison->members;
	}
	
	my %equip_places = map { $_->equip_place_name => $_ } $c->model('DBIC::Equip_Places')->search();

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'character/equipment_tab.html',
				params   => {
					character                     => $character,
					equipped_items                => $equipped_items,
					equipped_items_by_id          => \%equipped_items_by_id,
					equip_place_category_list     => \%equip_place_category_list,
					equip_places                  => \%equip_places,
					allowed_to_give_to_characters => \@allowed_to_give_to_characters,
					party                         => $c->stash->{party},
				}
			}
		]
	);
}

sub inventory : Local {
	my ( $self, $c ) = @_;

	my $character = $c->stash->{character};

	croak "Invalid character id" unless $character;

    my %items_in_grid = $character->items_in_grid;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'character/inventory.html',
				params   => {
					character => $character,
					party     => $c->stash->{party},
					items_in_grid => \%items_in_grid,
				}
			}
		]
	);
}

sub item_details : Local {
	my ( $self, $c ) = @_;

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
					item      => $item,
					item_type => $item->item_type,
				}
			}
		]
	);

}

sub split_item : Local {
   	my ( $self, $c ) = @_;
   	   	
	my $item = $c->model('DBIC::Items')->find(
		{
			'item_id' => $c->req->param('item_id'),
			'belongs_to_character.party_id' => $c->stash->{party}->id,
		},
		{
			prefetch => [
                'belongs_to_character',
                'item_variables',
            ],
            for => 'update',            
		}
	);
    
    $c->stash->{character} = $item->belongs_to_character;
    $c->forward('check_character_can_change_items');	
	
	return if $item->variable('Quantity') <= 0 || $item->variable('Quantity') <= $c->req->param('new_quantity') || $c->req->param('new_quantity') <= 0;
	
	my $new_item = $c->model('DBIC::Items')->create(
	   {
	       item_type_id => $item->item_type_id,
	       character_id => $item->character_id,
	   }
	);
	
	$new_item->variable_row('Quantity', $c->req->param('new_quantity'));
	$item->variable_row('Quantity', $item->variable('Quantity') - $c->req->param('new_quantity'));
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

	my $item = $c->model('DBIC::Items')->find( 
	   { 
	       item_id => $c->req->param('item_id'), 
	   }, 
	   { 
	       prefetch => { 'item_type' => { 'item_attributes' => 'item_attribute_name' } },
	       #for => 'update', 
	   }, 
    );

    my $character = $item->belongs_to_character;
    
    croak "Character not in party" unless $character->party_id == $c->stash->{party}->id;
    
    $c->stash->{character} = $character;
    $c->forward('check_character_can_change_items');

	my @slots_changed;
	my $equip_place = $c->req->param('equip_place');
	eval { @slots_changed = $item->equip_item($equip_place); };
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
			image     => $item->item_type->image,
			tooltip   => $c->forward( '/item/tooltip', [1] ),
			item_id   => $item->id,
		},
	);

	my $slots_cleared;
	if ( scalar @slots_changed > 1 ) {

		# More than one slot changed... clear anything that wasn't the slot we tried to equip to
		my @slots_to_clear = grep { $_ ne $c->req->param('equip_place') } @slots_changed;

		# Don't expect to get more than one slot changed (which might be a poor assumption)
		# Just warn for now if we have more than 1
		$c->log->warn("Found more than one slot to clear in equip_item") if scalar @slots_to_clear > 1;

		$ret{ $slots_to_clear[0] } = {
			item_type => undef,
			image     => undef,
			tooltip   => '',
			item_id   => undef,
		};
	}

	$c->res->body( to_json( { changed_slots => \%ret } ) );
}

sub give_item : Local {
	my ( $self, $c ) = @_;

	$c->forward('check_character_can_change_items');

	my $character = $c->stash->{character};

	my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), } );

	my $original_character = $item->belongs_to_character;

	croak "Item doesn't belong to character in the party" unless $original_character->party_id == $c->stash->{party}->id;
	
	if ($original_character->garrison_id) {
	    my $garrison = $original_character->garrison;
	    my $invalid_char = 0;
	    if ($c->stash->{party_location}->land_id == $garrison->land_id) {
	        # Party is in sector, so can give to chars in same garrison or in party
	        $invalid_char = 1 if $original_character->garrison_id != $character->garrison_id &&
	           ! $character->is_in_party;
	    }
	    else {	    
            # If party is not in sector, can only give to character in same garrison
             $invalid_char = 1 unless $original_character->garrison_id == $character->garrison_id;
	    }
	    
	    croak "Cannot give item to this character" if $invalid_char;
	}

	my $slot_to_clear = $item->equip_place_id ? $item->equipped_in->equip_place_name : undef;

	$item->equip_place_id(undef);
	$item->add_to_characters_inventory($character);
	$item->update;

	$c->res->body(
		to_json(
			{
				clear_equip_place => $slot_to_clear,
				encumbrance       => $character->encumbrance,
			}
		)
	);
}

sub drop_item : Local {
	my ( $self, $c ) = @_;

	$c->forward('check_character_can_change_items');

	my $character = $c->stash->{character};

	my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), } );

	my $original_character = $item->belongs_to_character;

	croak "Item doesn't belong to character in the party" unless $original_character->party_id == $c->stash->{party}->id;

	my $slot_to_clear = $item->equip_place_id ? $item->equipped_in->equip_place_name : undef;
	
	if ( $character->garrison_id ) {
		$item->land_id( $character->garrison->land_id );
		$item->character_id(undef);
		$item->equip_place_id(undef);
		$item->update;        
	}
	if ( $c->stash->{party_location}->town ) {

		# If we're in a town, just delete the item...
		# TODO: Could think of something better to do here...
		$item->delete;
	}
	else {
		$item->land_id( $c->stash->{party_location}->id );
		$item->character_id(undef);
		$item->equip_place_id(undef);
		$item->update;
	}

	$c->res->body(
		to_json(
			{
				clear_equip_place => $slot_to_clear,
			}
		)
	);
}

sub unequip_item : Local {
	my ( $self, $c ) = @_;

	$c->forward('check_character_can_change_items');

	my $character = $c->stash->{character};

	my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), } );

	# Make sure this item belongs to a character in the party
	if ( $item->character_id != $character->id ) {
		$c->log->warn( "Attempted to unequip item  "
				. $item->id
				. " within party "
				. $c->stash->{party}->id
				. ", but item does not belong to this party (item is owned by character: "
				. $item->character_id
				. ")" );
		return;
	}

	return unless $item->equip_place_id;

	my $slot_to_clear = $item->equipped_in->equip_place_name;

	$item->equip_place_id(undef);
	$item->update;

	$c->res->body(
		to_json(
			{
				clear_equip_place => $slot_to_clear,
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
		$character->online_cast_chance($c->req->param('online_cast_chance'));
		$character->offline_cast_chance($c->req->param('offline_cast_chance'));
		$character->update;

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

			$memorised_spell->cast_offline( $c->req->param( 'cast_offline_' . $spell_id ) ? 1 : 0 );

			$memorised_spell->memorise_count_tomorrow($mem_count);
			$memorised_spell->update;
		}
	}

    $c->forward( '/panel/refresh', [[screen => 'character/view?selected=spells&character_id=' . $character->id], 'party'] );
}

sub skills : Local {
    my ( $self, $c ) = @_;
   
   	my $character = $c->stash->{character};

	return unless $character;
	
	my @known_skills =$c->model('DBIC::Skill')->search(
	   {
	       'character_skills.character_id' => $character->id,
	   },
	   {
	       prefetch => 'character_skills',
	       order_by => 'skill_name',
	   }
	);
	
	my $can_assign_skill_points = $character->party_id && $character->skill_points > 0 ? 1 : 0;
	
	my @available_skills;
	if ($can_assign_skill_points) {
	    my @skills = $c->model('DBIC::Skill')->search(
	       {},
	       {
	           order_by => 'skill_name',
	       },	    
	    );
	    
	    foreach my $skill (@skills) {
	       # Remove all skills that are already know by this character
	       if (! grep { $_->id == $skill->id } @known_skills) {
	           push @available_skills, $skill;   
	       }   
	    }	    
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'character/skills.html',
				params   => {
					character              => $character,
                    known_skills           => \@known_skills,
                    available_skills       => \@available_skills,
                    can_assign_skill_points => $can_assign_skill_points,
				}
			}
		]
	);
}

sub use_skill_point : Local {
    my ( $self, $c ) = @_;
    
    $c->forward('check_action_allowed');
    
    # Re-read character and lock for update
	my $character = $c->model('DBIC::Character')->find( 
	   { 
	       character_id => $c->stash->{character}->id,
	   }, 
	   { 
	       for => 'update', 
	   },
	);
    
    if ($character->skill_points <= 0) {
        $c->stash->{error} = 'No stat points to assign';
        $c->forward( '/panel/refresh' );
        return;
    }
    
    my $skill = $c->model('DBIC::Skill')->find({ skill_id => $c->req->param('skill_id') });
    croak "Invalid skill\n" unless $skill;
    
    my $character_skill = $c->model('DBIC::Character_Skill')->find_or_create(
        {
            character_id => $character->id,
            skill_id => $skill->id,
        },
        {
            for => 'update',
        },
    );
    
    if ($character_skill->level >= $c->config->{max_skill_level}) {
        $c->stash->{error} = 'That skill is already at the max level!';
        $c->forward( '/panel/refresh' );
        return;
    }
    
    $character_skill->increment_level;
    $character_skill->update;
    
    $character->decrement_skill_points;
    $character->update;
    
    $c->forward( '/panel/refresh', [[screen => 'character/view?selected=skills&character_id=' . $character->id], 'party'] );
    
}

sub add_stat_point : Local {
	my ( $self, $c ) = @_;

	$c->forward('check_action_allowed');

    # Re-read character and lock for update
	my $character = $c->model('DBIC::Character')->find( 
	   { 
	       character_id => $c->stash->{character}->id,
	   }, 
	   { 
	       for => 'update', 
	   },
	);

	unless ( $character->stat_points != 0 ) {
		$c->res->body( to_json( { error => 'No stat points to add' } ) );
		return;
	}

	if ( my $stat = $character->get_column( $c->req->param('stat') ) ) {
		$character->set_column( $c->req->param('stat'), $stat + 1 );
		$character->stat_points( $character->stat_points - 1 );
		$character->calculate_attack_factor;
		$character->calculate_defence_factor;
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
	
	$c->forward( '/panel/refresh', [[screen => 'character/view?character_id=' . $character->id], 'party'] );

}

sub bury : Local {
	my ( $self, $c ) = @_;
	
	my $hs = HTML::Strip->new();

	$c->forward('check_action_allowed');

	my $character = $c->stash->{character};
	
	croak "Cannot bury while in combat" if $c->stash->{party}->in_combat;

	$c->model('DBIC::Grave')->create(
		{
			character_name => $character->character_name,
			land_id        => $c->stash->{party_location}->id,
			day_created    => $c->stash->{today}->day_number,
			epitaph        => $hs->parse($c->req->param('epitaph')),
		}
	);

	$c->stash->{messages} = "You say your last goodbyes to " . $character->character_name . ". R.I.P.";

	$character->delete;

	$c->stash->{party}->adjust_order;

	$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'party' ] );

}

sub check_action_allowed : Private {
	my ( $self, $c ) = @_;

	unless ( $c->stash->{character}->party_id == $c->stash->{party}->id ) {
		croak "Can only make changes to a character in your party\n";
	}
}

sub check_character_can_change_items : Private {
	my ( $self, $c ) = @_;

	unless ( $c->stash->{character}->item_change_allowed ) {
		croak "Attempt to change items on a character that is not allowed to do so\n";
	}
}


1;
