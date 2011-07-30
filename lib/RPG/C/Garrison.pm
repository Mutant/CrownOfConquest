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
	
	$c->stash->{garrison} = $c->model('DBIC::Garrison')->find(
		{
			garrison_id => $c->req->param('garrison_id'),
			party_id => $c->stash->{party}->id,
		},
		{
			prefetch => ['characters', 'land'],
		}
	);
		
	return 1;	
}

sub create : Local {
	my ($self, $c) = @_;
	
	$c->forward('RPG::V::TT',
        [{
            template => 'garrison/create.html',
            params => {
            	flee_threshold => 70, # default
            	party => $c->stash->{party},
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
	
	croak "Illegal garrison creation - garrison not allowed here" unless $c->stash->{party_location}->garrison_allowed;

	my @char_ids_to_garrison = $c->req->param('chars_in_garrison');
		
	croak "Must have at least one char in the garrison" unless @char_ids_to_garrison;
	
	my @characters = $c->stash->{party}->characters_in_party;
	
	if (scalar @char_ids_to_garrison == scalar @characters) {
		croak "Must keep at least one character in the party";
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
	
	$c->model('DBIC::Character')->search(
		{
			character_id => \@char_ids_to_garrison,
			party_id => $c->stash->{party}->id,
		}
	)->update(
		{
			garrison_id => $garrison->id,
		}
	);
	
	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We created a garrison at " . $garrison->land->x . ", " . $garrison->land->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);
	
	$c->stash->{party}->adjust_order;
	$c->stash->{party}->turns($c->stash->{party}->turns - $c->config->{garrison_creation_turn_cost});
	$c->stash->{party}->update;
	
	$c->forward('add_to_town_news', ['create']);
	
	my $messages = $c->forward( '/quest/check_action', [ 'garrison_created', $garrison ] );
	$c->flash->{message} = $messages->[0] if $messages && @$messages;
	
	$c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $garrison->id], 'messages', 'party'] );
}

sub update : Local {
	my ($self, $c) = @_;
	
	croak "Can't find garrison" unless $c->stash->{garrison};
	
	croak "Must be in correct sector to update garrison" unless $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;
	
	my @current_garrison_chars = $c->stash->{garrison}->characters;
		
	my %char_ids_to_garrison = map { $_ => 1 } $c->req->param('chars_in_garrison');
	
	croak "Must have at least one char in the garrison" unless %char_ids_to_garrison;
	
	my @chars_in_party = $c->stash->{party}->characters_in_party;
	if (scalar keys(%char_ids_to_garrison) - scalar @current_garrison_chars == scalar @chars_in_party) {
		croak "Must keep at least one character in the party";
	}
	
	my %chars_by_id = map { $_->id => $_ } (@chars_in_party, @current_garrison_chars);
	if ((grep { ! $chars_by_id{$_}->is_dead } keys %char_ids_to_garrison ) <= 0 ) {
		$c->stash->{error} = "You must have at least one living character in the garrison";
		$c->detach( '/panel/refresh' );
	}
	
	my @chars_left_in_party = @{ set(keys %chars_by_id) - set(keys %char_ids_to_garrison) };
	if ((grep { ! $chars_by_id{$_}->is_dead } @chars_left_in_party) <= 0 ) {
		$c->stash->{error} = "You must have at least one living character in your party";
		$c->detach( '/panel/refresh' );
	}	

	if (scalar @chars_left_in_party > $c->config->{max_party_characters}) {
		$c->stash->{error} = "You can't have more than " . $c->config->{max_party_characters} . " characters in your party";
		$c->detach( '/panel/refresh' );
		return;		
	}
	
	my @chars_to_remove;
	foreach my $current_char (@current_garrison_chars) {
		if (! $char_ids_to_garrison{$current_char->id}) {
			# Char removed
			push @chars_to_remove, $current_char;
		}
	}
	
	foreach my $char (@current_garrison_chars) {
		$char->garrison_id(undef);
		$char->update;
	}
	
	$c->model('DBIC::Character')->search(
		{
			character_id => [keys %char_ids_to_garrison],
			party_id => $c->stash->{party}->id,
		}
	)->update(
		{
			garrison_id => $c->stash->{garrison}->id,
		}
	);	
	
	$c->stash->{party}->adjust_order;
	
	$c->forward( '/panel/refresh', [[screen => 'garrison/manage?garrison_id=' . $c->stash->{garrison}->id], 'party'] );
	
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
		
		$c->stash->{party}->adjust_order;

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
                    editable => $c->stash->{party_location}->id == $c->stash->{garrison}->land->id,
                },
            }
        ]
    );		
}

sub character_tab : Local {
	my ($self, $c) = @_;

	my $editable = $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/characters.html',
                params   => {
                    garrison => $c->stash->{garrison},
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

sub get_owned_equipment : Local {
	my ($self, $c, $party_id, $garrison_id) = @_;
	return $c->model('DBIC::Items')->search(
        	{ 
	        	-or => ['belongs_to_character.garrison_id' => $garrison_id,
	        			'belongs_to_character.party_id' => $party_id]
	        },
	        {
	        	join => 'belongs_to_character',
	            prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
	            order_by => 'item_category',
	        },
	);
}


sub equipment_tab : Local {
	my ($self, $c) = @_;
	
	my $editable = $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;
	
	my @party_equipment;
	
	if ($editable) {
		@party_equipment = $c->model('DBIC::Items')->search(
        	{ 
	        	'belongs_to_character.garrison_id' => undef,
	        	'belongs_to_character.mayor_of' => undef,
	        	'belongs_to_character.status' => undef,
	        	'belongs_to_character.party_id' => $c->stash->{party}->id, 
	        },
	        {
	        	join => 'belongs_to_character',
	            prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
	            order_by => 'item_category',
	        },
	    );
	}
    
	my @garrison_equipment = $c->model('DBIC::Items')->search(
        { 
        	'garrison_id' => $c->stash->{garrison}->id, 
        },
        {
            prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
            order_by => 'item_category',
        },
    );    
    
    my @categories = $c->model('DBIC::Item_Category')->search( { hidden => 0 }, { order_by => 'item_category', }, );
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/equipment.html',
                params   => {
                	party_equipment => \@party_equipment,
                	garrison_equipment => \@garrison_equipment,
                	characters => [$c->stash->{party}->characters_in_party],
                	categories => \@categories,
                	garrison => $c->stash->{garrison},
                	party => $c->stash->{party},
                	editable => $editable,
                },
            }
        ]
    );		
}

sub move_item : Local {
	my ($self, $c) = @_;
	
	my $editable = $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;
	
	return unless $editable;
	
	my $item = $c->model('DBIC::Items')->find($c->req->param('item_id'));
	
	croak "Item not found" unless $item;
	
	my @characters = $c->stash->{party}->characters_in_party;
	
	if ($item->garrison_id == $c->stash->{garrison}->id) {
		# Move back to party
		my $character = (shuffle @characters)[0];
		$item->add_to_characters_inventory($character);
	}
	else {
		# Add to garrison, if it belonged to one of the party's characters
		if (grep { $_->id == $item->character_id } @characters) {
			$item->garrison_id($c->stash->{garrison}->id);
			$item->character_id(undef);
			$item->equip_place_id(undef);
			$item->update;
		}
	}
}

sub adjust_gold : Local {
	my ($self, $c) = @_;
	
	my $editable = $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;
	
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

1;