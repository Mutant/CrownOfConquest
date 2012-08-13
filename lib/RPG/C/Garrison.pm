package RPG::C::Garrison;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use Data::Dumper;

use JSON;
use List::Util qw(shuffle);
use Set::Object qw(set);
use HTML::Strip;

sub auto : Private {
	my ($self, $c) = @_;
	
	if ($c->req->param('garrison_id')) {
    	$c->stash->{garrison} = $c->model('DBIC::Garrison')->find(
    		{
    			garrison_id => $c->req->param('garrison_id'),
    			party_id => $c->stash->{party}->id,
    		},
    		{
    			prefetch => ['characters', 'land'],
    			order_by => 'characters.character_name',
    		}
    	);
	}
		
	return 1;	
}

sub create : Local {
	my ($self, $c) = @_;
	
	undef $c->session->{new_garrison};
	
	$c->forward('RPG::V::TT',
        [{
            template => 'garrison/create.html',
            params => {
            	flee_threshold => 70, # default
            	party => $c->stash->{party},
            	party_chars => [ $c->stash->{party}->members ],
            	turn_cost => $c->config->{garrison_creation_turn_cost},
            },
        }]
    );			
}

sub add : Local {
	my ($self, $c) = @_;
	
	if ( $c->stash->{party}->level < $c->config->{minimum_garrison_level} ) {
		$c->stash->{error} = "You can't create a garrison - your party level is too low";
		$c->detach( '/panel/refresh' );
	}
	
	if ( $c->stash->{party}->turns < $c->config->{garrison_creation_turn_cost} ) {
		$c->stash->{error} = "You need at least " . $c->config->{garrison_creation_turn_cost} . " to create a garrison";
		$c->detach( '/panel/refresh' );
	}
	
	croak "Illegal garrison creation - garrison not allowed here" unless $c->stash->{party_location}->garrison_allowed($c->stash->{party});

    if (! $c->session->{new_garrison} || ref $c->session->{new_garrison} ne 'ARRAY') {
	   $c->stash->{error} = "You must add at least one character to the garrison";
	   $c->detach( '/panel/refresh' );
    }

	my @char_ids_to_garrison = @{ $c->session->{new_garrison} };	
	
	my @characters = $c->stash->{party}->characters_in_party;
	
	if (scalar @char_ids_to_garrison == scalar @characters) {
	   $c->stash->{error} = "You must keep at least one character in the party";
	   $c->detach( '/panel/refresh' );
	}
	
	my %chars_by_id = map { $_->id => $_ } @characters;
	if ((grep { ! $chars_by_id{$_}->is_dead } @char_ids_to_garrison) <= 0 ) {
		$c->stash->{error} = "You must have at least one living character in the garrison";
		$c->detach( '/panel/refresh' );
	}
	
	my @chars_left_in_party = @{ set(keys %chars_by_id) - set(@char_ids_to_garrison) };
	if ((grep { ! $chars_by_id{$_}->is_dead } @chars_left_in_party) <= 0 ) {
		$c->stash->{error} = "You must have at least one living character in your party";
		$c->detach( '/panel/refresh' );		
	}

	undef $c->session->{new_garrison};
	
	my $hs = HTML::Strip->new();
	my $name = $hs->parse($c->req->param('name'));
	
	my $garrison = $c->model('DBIC::Garrison')->create(
		{
			land_id => $c->stash->{party_location}->land_id,
			party_id => $c->stash->{party}->id,
			creature_attack_mode => 'Attack Weaker Opponents',
			party_attack_mode => 'Defensive Only',
			name => $name || undef,
		}
	);
	
	$garrison->organise_equipment;
	
	my @garrison_chars = $c->model('DBIC::Character')->search(
		{
			character_id => \@char_ids_to_garrison,
			party_id => $c->stash->{party}->id,
		}
	);
	
	foreach my $char (@garrison_chars) {
	   $char->update(
    		{
    			garrison_id => $garrison->id,
    		}
    	);
	}
	
	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We created a garrison at " . $garrison->land->x . ", " . $garrison->land->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);
	
	$c->stash->{party}->turns($c->stash->{party}->turns - $c->config->{garrison_creation_turn_cost});
	$c->stash->{party}->update;
	
	$c->forward('add_to_town_news', ['create']);
	
	my $messages = $c->forward( '/quest/check_action', [ 'garrison_created', $garrison ] );
	$c->flash->{message} = $messages->[0] if $messages && @$messages;
	
	$c->forward('/map/refresh_current_loc');
	
	$c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $garrison->id], 'messages', 'party'] );
}

sub character_move : Local {
    my ($self, $c) = @_;

    my $character = $c->model('DBIC::Character')->find(
        {
            'character_id' => $c->req->param('character_id'),
            'party_id' => $c->stash->{party}->id,
        },
    );
  
    croak "Invalid character" unless $character;

    my $swap_char;
    if ($c->req->param('swapped_char_id')) {
        $swap_char = $c->model('DBIC::Character')->find(
            {
                'character_id' => $c->req->param('swapped_char_id'),
                'party_id' => $c->stash->{party}->id,
            },
        );
        
        croak "Invalid swap char" unless $swap_char; 
    }
    else {
        # We're not swapping, so make sure the garrison/party isn't already full
        if ($c->req->param('to') eq 'party') {
            croak "Party full" if scalar($c->stash->{party}->members) >= $c->config->{max_party_characters};   
        }
        elsif ($c->stash->{garrison}) {
            croak "Garrison full" if scalar($c->stash->{garrison}->members) >= 8;                 
        }
        elsif ($c->session->{new_garrison}) {
            croak "Garrison full" if scalar @{ $c->session->{new_garrison} } >= 8;
        }
    }
    
    if (! $c->stash->{garrison}) {
        # Garrison not created yet...
        if ($c->req->param('to') eq 'garrison') {
            push @{$c->session->{new_garrison}}, $character->id;
            
            if ($swap_char) {
                $c->session->{new_garrison} = [ grep { $_ != $swap_char->id } @{$c->session->{new_garrison}} ];    
            }
        } 
        elsif ($c->session->{new_garrison}) {
            $c->session->{new_garrison} = [ grep { $_ != $character->id } @{$c->session->{new_garrison}} ];
            
            if ($swap_char) {
                push @{$c->session->{new_garrison}}, $swap_char->id;
            }
        }
    }
    
    elsif ($c->req->param('to') eq 'garrison') {
        croak "Attempting to move character into garrison from outside party" unless $character->is_in_party;
        $character->garrison_id($c->stash->{garrison}->garrison_id);
        
        croak "Can't remove last living character from party" 
            if ! $swap_char && $c->stash->{party}->number_alive <= 1 && ! $character->is_dead;            
        
        if ($swap_char) {
            croak "Attempting to swap out char not in garrison" unless $swap_char->garrison_id == $c->stash->{garrison}->garrison_id;
            $swap_char->garrison_id(undef);   
        }
    }
    else {
        croak "Attempting to move character out of garrison when not in garrison" unless $character->garrison_id == $c->stash->{garrison}->garrison_id;
        $character->garrison_id(undef);
        
        croak "Can't remove last living character from garrison" 
            if ! $swap_char && $c->stash->{garrison}->number_alive <= 1 && ! $character->is_dead;        
        
        if ($swap_char) {
            croak "Attempting to swap out char not in party" unless $swap_char->is_in_party;
            $swap_char->garrison_id($c->stash->{garrison}->garrison_id);            
        }
    }
    
    $character->update;
    $swap_char->update if $swap_char;
    
    # See if we've got the min number of chars in the party/garrison
    my %ret;
    if ($c->stash->{party}->number_alive <= 1) {
        $ret{no_party_move} = 1;
    }
    
    if ($c->stash->{garrison} && $c->stash->{garrison}->number_alive <= 1) {
        $ret{no_garrison_move} = 1;   
    }
        
    $c->res->body(to_json \%ret);    
}

sub remove : Local {
	my ($self, $c) = @_;
	
	confess "Can't find garrison" unless $c->stash->{garrison};
	
	my @garrison_characters = $c->stash->{garrison}->characters;
	my @characters = $c->stash->{party}->characters_in_party;

	if (scalar @garrison_characters + scalar @characters > $c->config->{max_party_characters}) {
		$c->stash->{error} = "You can't remove this garrison - " .
			"adding these characters would give you more than " . $c->config->{max_party_characters} . " characters in the party";
		$c->detach( '/panel/refresh' );
	}
	else {	
		foreach my $character (@garrison_characters) {
			$character->garrison_id(undef);
			$character->update;	
		}

		$c->model('DBIC::Party_Messages')->create(
			{
				message => "We disbanded our garrison at " . $c->stash->{garrison}->land->x . ", " . $c->stash->{garrison}->land->y,
				alert_party => 0,
				party_id => $c->stash->{party}->id,
				day_id => $c->stash->{today}->id,
			}
		);		

		# Move equipment and gold back to party
		foreach my $item ($c->stash->{garrison}->items) {
			my $character = (shuffle @characters)[0];
			$item->add_to_characters_inventory($character);
		}
		
		$c->forward('add_to_town_news', ['remove']);
		
		$c->stash->{party}->increase_gold($c->stash->{garrison}->gold);
		$c->stash->{party}->update;

		my $messages = $c->forward( '/quest/check_action', [ 'garrison_removed', $c->stash->{garrison} ] );
	    $c->stash->{messages} = $messages if $messages && @$messages;

		$c->stash->{garrison}->land_id(undef);
		$c->stash->{garrison}->update;
		
		$c->stash->{panel_messages} = ['Garrison Removed'];
		
		$c->forward('/map/refresh_current_loc');
		
		$c->forward( '/panel/refresh', [[screen => 'close'], 'messages', 'party'] );		
	}
}

sub add_to_town_news : Private {
	my ($self, $c, $action) = @_;
	
	my $template = $action eq 'create' ? 'creation_news.html' : 'removal_news.html';

	# Add to town news
    my @towns = $c->model('DBIC::Town')->find_in_range(
        {
            x => $c->stash->{party_location}->x,
            y => $c->stash->{party_location}->y,
        },
        $c->config->{nearby_town_range},
    );
    
    if (@towns) {
    	my $message = $c->forward('RPG::V::TT',
	        [{
	            template => "garrison/$template",
	            params => {
	            	land => $c->stash->{party_location},
	            	party => $c->stash->{party},
	            },
	            return_output => 1,
	        }]
	    );
    
	    foreach my $town (@towns) {
            $c->model('DBIC::Town_History')->create(
                {
                    town_id => $town->id,
                    day_id  => $c->stash->{today}->id,
                    message => $message,
                }
            );    		
	    }
    }	
	
}

sub manage : Local {
	my ($self, $c) = @_;
	
	confess "Can't find garrison" unless $c->stash->{garrison};
	
	my @party_garrisons = $c->stash->{party}->garrisons;
	
	my $building = $c->stash->{garrison}->land->building;
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/manage.html',
                params   => {
                    garrison => $c->stash->{garrison},
                    party_garrisons => \@party_garrisons,
                    selected => $c->req->param('selected') || '',
                    message => $c->flash->{message} || undef,
                    editable => $self->is_editable($c),
                    has_building => $building && $building->allowed_to_manage($c->stash->{party}),
                },
            }
        ]
    );		
}

sub is_editable {
    my ($self, $c) = @_;
    
    return $c->stash->{garrison} && $c->stash->{party_location}->id == $c->stash->{garrison}->land->id && ! $c->stash->{party}->in_combat ? 1 : 0;
}

sub character_tab : Local {
	my ($self, $c) = @_;

	my $editable = $self->is_editable($c);

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/characters.html',
                params   => {
                    garrison => $c->stash->{garrison},
                    garrison_chars => [ $c->stash->{garrison}->characters ],
                    party_chars => [ $c->stash->{party}->members ],
                    editable => $editable,
                    party => $c->stash->{party},
                },
            }
        ]
    );	
}

sub combat_log_tab : Local {
	my ($self, $c) = @_;
	
    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_garrison( $c->stash->{garrison}, 20 );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/combat_log.html',
                params   => {
                    logs  => \@logs,
                    garrison => $c->stash->{garrison},
                    old_party => $c->stash->{garrison}->land_id ? 0 : 1,
                },
            }
        ]
    );	
}

sub orders_tab : Local {
	my ($self, $c) = @_;
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/orders.html',
                params   => {
                    garrison => $c->stash->{garrison},
                },
                fill_in_form => {$c->stash->{garrison}->get_columns},
            }
        ]
    );	
}

sub update_orders : Local {
	my ($self, $c) = @_;
	
	$c->stash->{garrison}->creature_attack_mode($c->req->param('creature_attack_mode'));
	$c->stash->{garrison}->party_attack_mode($c->req->param('party_attack_mode'));
	$c->stash->{garrison}->flee_threshold($c->req->param('flee_threshold'));
	$c->stash->{garrison}->attack_parties_from_kingdom($c->req->param('attack_parties_from_kingdom') ? 1 : 0);
	$c->stash->{garrison}->attack_friendly_parties($c->req->param('attack_friendly_parties') ? 1 : 0);
	$c->stash->{garrison}->update;
	
	$c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $c->stash->{garrison}->id . '&selected=orders']] );
}

sub messages_tab : Local {
	my ($self, $c) = @_;

    my @messages = $c->model('DBIC::Garrison_Messages')->search(
        { 'garrison_id' => $c->stash->{garrison}->id, },
        {
            order_by => 'day.date_started desc',
            prefetch => 'day',
        },
    );

    my %message_logs;
    foreach my $message (@messages) {
        push @{ $message_logs{ $message->day->day_number } }, $message->message;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/history.html',
                params   => {
                    message_logs   => \%message_logs,
                    today          => $c->stash->{today},
                    history_length => 7,
                },
            }
        ]
    );	
}


sub equipment_tab : Local {
	my ($self, $c) = @_;
	
	my $editable = $self->is_editable($c);
	
	my @characters = $editable ? $c->stash->{party}->characters_in_sector : $c->stash->{garrison}->members;
	
	my $items_in_grid = $c->stash->{garrison}->items_in_grid;
		
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/equipment.html',
                params   => {
                	items_in_grid => $items_in_grid,
                	characters => \@characters,
                	garrison => $c->stash->{garrison},
                	party => $c->stash->{party},
                	editable => $editable,
                	tabs => [$c->stash->{garrison}->tabs],
                },
            }
        ]
    );		
}

sub transfer_item : Local {
	my ($self, $c) = @_;
	
	# May not have been passed garrison id, see if there's one in the sector
	$c->stash->{garrison} //= $c->stash->{party_location}->garrison;
	
	my $editable = $self->is_editable($c);
	
	my $item = $c->model('DBIC::Items')->find($c->req->param('item_id'));
	
	croak "Item not found" unless $item;

	my $garrison = $c->stash->{garrison};
	if (! $garrison) {
       # Transfer is from garrison to character. The request doesn't have a garrison id,
       #  so, get it from the character we're transferring to
       my $character = $c->model('DBIC::Character')->find(
           {
               character_id => $c->req->param('character_id'),
               party_id => $c->stash->{party}->id,
           }
       );
       croak "Can't find character" unless $character;
       $garrison = $character->garrison;
    }
	
	confess "Couldn't find garrison (editable: $editable)" unless $garrison;
	
	croak "Garrison not owned by party" if $garrison->party_id != $c->stash->{party}->id;
	
	my @characters = $editable ? $c->stash->{party}->characters_in_sector : $garrison->members;
		
	if ($item->garrison_id == $garrison->id) {
		# Move back to party
		my ($character) = grep { $_->id == $c->req->param('character_id') } @characters;

        if ($c->req->param('equip_place')) {
            $item->character_id($character->id);
	        $item->update;     
            my $ret = $c->forward('/character/equip_item_impl', [$item]);
            $item->add_to_characters_inventory($character);
           
            $c->res->body( to_json( $ret ) );
        }
        else {
            $item->add_to_characters_inventory($character, { x => $c->req->param('grid_x'), y => $c->req->param('grid_y') }, 0);
        }
		$garrison->remove_item_from_grid($item);
	}
	else {
		# Add to garrison, if it belonged to one of the allowed characters
		if (grep { $_->id == $item->character_id } @characters) {    
		    
			$item->garrison_id($garrison->id);			
			$item->belongs_to_character->remove_item_from_grid($item);
			$item->character_id(undef);
			$item->equip_place_id(undef);
			$garrison->add_item_to_grid( $item, { x => $c->req->param('grid_x'), y => $c->req->param('grid_y') }, $c->req->param('tab')); 
			$item->update;			
		}
	}
}

sub move_item : Local {
    my ($self, $c) = @_;
    
	my $garrison = $c->stash->{garrison};
	
	my $item = $c->model('DBIC::Items')->find( 
	   { 
	       item_id => $c->req->param('item_id'), 
	       garrison_id => $garrison->id 
	   },
	   {
	       prefetch => 'item_type',
	   }, 
	);
	
	croak "Invalid item" unless $item;
	
    $garrison->remove_item_from_grid($item);
    $garrison->add_item_to_grid($item, { x => $c->req->param('grid_x'), y => $c->req->param('grid_y') } );    
}

sub organise_equipment : Local {
    my ($self, $c) = @_;
    
	my $garrison = $c->stash->{garrison};
	
	$garrison->organise_equipment;
	
	my $items_in_grid = $garrison->items_in_grid;
		
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'garrison/equip_grid.html',
				params   => {
				    items_in_grid => $items_in_grid,
				}
			}
		]
	);    
}

sub item_tab : Local {
	my ( $self, $c ) = @_;
    
	my $items_in_grid = $c->stash->{garrison}->items_in_grid($c->req->param('tab'));	

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'garrison/equip_grid.html',
				params   => {
					items_in_grid => $items_in_grid,
					tab => $c->req->param('tab'),
				}
			}
		]
	);
}

sub character_inventory : Local {
    my ( $self, $c ) = @_;
    	
    $c->visit('/character/equipment_tab');
}

sub adjust_gold : Local {
	my ($self, $c) = @_;
	
	my $editable = $self->is_editable($c);
	
	return unless $editable;
	
	my $party = $c->stash->{party};
	my $garrison = $c->stash->{garrison};
		
	if ($c->req->param('action') eq 'add' && $party->gold < $c->req->param('gold')) {
	    $c->stash->{error} = "You don't have enough party gold to add that amount to the garrison";   
	    $c->detach('/panel/refresh');
	}

	if ($c->req->param('action') eq 'take' && $garrison->gold < $c->req->param('gold')) {
	    $c->stash->{error} = "There's not enough gold in the garrison to take that amount";   
	    $c->detach('/panel/refresh');
	}
	
	if ($c->req->param('action') eq 'add') {
	   $party->decrease_gold($c->req->param('gold'));
	   $garrison->increase_gold($c->req->param('gold'));
	}
	if ($c->req->param('action') eq 'take') {
	   $garrison->decrease_gold($c->req->param('gold'));
	   $party->increase_gold($c->req->param('gold'));	    
	}
	
	$party->update;	
	$garrison->update;
	
	$c->forward('/panel/refresh', ['party_status', ['screen' => 'garrison/manage?garrison_id=' . $garrison->id]]);
}

sub update_garrison_name : Local {
	my ($self, $c) = @_;
	
	$c->stash->{garrison}->name($c->req->param('name') || undef);
	$c->stash->{garrison}->update;
	
	$c->res->body(
		to_json(
			{
				new_name => $c->stash->{garrison}->display_name(1),
			}
		)
	);
}

sub building_tab : Local {
	my ($self, $c) = @_;
	
	$c->stash->{building_url_prefix} = 'garrison/building_';
	
	$c->stash->{building} = $c->stash->{garrison}->land->building;
	
	$c->forward('/building/manage');   
}

sub building_upgrade : Local {
    my ($self, $c) = @_;
    
    my $garrison = $c->model('DBIC::Garrison')->find(
		{
			party_id => $c->stash->{party}->id,
			land_id => $c->stash->{party_location}->id,
		},
	);
    $c->stash->{no_refresh} = 1;
    
    $c->stash->{building} = $garrison->land->building;
    
    $c->forward('/building/upgrade');    
    
    $c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $garrison->id . '&selected=building'], 'party_status', 'messages'] );
    
}

sub building_build_upgrade : Local {
    my ($self, $c) = @_;
    
    my $garrison = $c->model('DBIC::Garrison')->find(
		{
			party_id => $c->stash->{party}->id,
			land_id => $c->stash->{party_location}->id,
		},
	);
    $c->stash->{no_refresh} = 1;
    
    $c->stash->{building} = $garrison->land->building;
    
    $c->forward('/building/build_upgrade');    
    
    $c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $garrison->id . '&selected=building'], 'party_status', 'messages'] );
    
}

sub building_cede : Local {
    my ($self, $c) = @_;
    
    my $garrison = $c->model('DBIC::Garrison')->find(
		{
			party_id => $c->stash->{party}->id,
			land_id => $c->stash->{party_location}->id,
		},
	);
    $c->stash->{no_refresh} = 1;
    
    $c->stash->{building} = $garrison->land->building;
    
    $c->forward('/building/cede');    
    
    $c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $garrison->id . '&selected=building'], 'messages', 'party_status'] );    
}

sub building_raze : Local {
    my ($self, $c) = @_;
    
    my $garrison = $c->model('DBIC::Garrison')->find(
		{
			party_id => $c->stash->{party}->id,
			land_id => $c->stash->{party_location}->id,
		},
	);
    $c->stash->{no_refresh} = 1;
    
    $c->stash->{building} = $garrison->land->building;
    
    $c->forward('/building/raze');    
    
    $c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $garrison->id . '&selected=building'], 'messages', 'party_status'] );    
}

1;