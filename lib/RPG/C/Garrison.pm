package RPG::C::Garrison;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use Data::Dumper;

use JSON;
use List::Util qw(shuffle);
use Set::Object qw(set);

sub auto : Private {
	my ($self, $c) = @_;
	
	$c->stash->{garrison} = $c->model('DBIC::Garrison')->find(
		{
			garrison_id => $c->req->param('garrison_id'),
			party_id => $c->stash->{party}->id,
			land_id => {'!=', undef},
		},
		{
			prefetch => ['characters', 'land'],
		}
	);
	
	#  Get the resource and tool category id.  TODO: could these be cached elsewhere?	
	$c->stash->{resource_category} = $c->model('DBIC::Item_Category')->find({'item_category' => 'Resource'});
	$c->stash->{tool_category} = $c->model('DBIC::Item_Category')->find({'item_category' => 'Tool'});
	
	@{$c->stash->{building_types}} = $c->model('DBIC::Building_Type')->search({}, { order_by => ['class', 'level asc' ] } );

	@{$c->stash->{resource_and_tools}} = $c->model('DBIC::Item_Type')->search(
		{	-or => [
				'item_category_id' => $c->stash->{resource_category}->item_category_id,
				'item_category_id' => $c->stash->{tool_category}->item_category_id
			] },
		{ order_by => 'item_type' }
	);
	
	# Create a hash of the items to image name.
	foreach my $next_resource (@{$c->stash->{resource_and_tools}}) {
		$c->stash->{resource_images}{$next_resource->item_type} = $next_resource->image;
	}
	
	foreach my $next_type (@{$c->stash->{building_types}}) {
		my %this_type = ('name' => $next_type->name, 'image' => $next_type->image, 'defense' => $next_type->defense_factor+0,
		  'attack' => $next_type->attack_factor+0,  'heal' => $next_type->heal_factor+0,  'commerce' => $next_type->commerce_factor+0,
		  'building_type_id' => $next_type->building_type_id, 'class' => $next_type->class, 'level' => $next_type->level);
		#Carp::carp("Next type:".Dumper(%this_type));
		
		my @resource_needs;
		if ($next_type->clay_needed > 0) {
			push(@resource_needs, {'res_name', 'Clay', 'amount', $next_type->clay_needed+0, 'image',
				$c->stash->{resource_images}{'Clay'}});
		}
		if ($next_type->iron_needed > 0) {
			push(@resource_needs, {'res_name', 'Iron', 'amount', $next_type->iron_needed+0, 'image',
				$c->stash->{resource_images}{'Iron'}});
		}
		if ($next_type->stone_needed > 0) {
			push(@resource_needs, {'res_name', 'Stone', 'amount', $next_type->stone_needed+0, 'image',
				$c->stash->{resource_images}{'Stone'}});
		}
		if ($next_type->wood_needed > 0) {
			push(@resource_needs, {'res_name', 'Wood', 'amount', $next_type->wood_needed+0, 'image',
				$c->stash->{resource_images}{'Wood'}});
		}
		$this_type{'resources_needed'} = \@resource_needs;
		$c->stash->{building_info}{$next_type->building_type_id} = \%this_type;
		#Carp::carp("Resource needs:".Dumper($c->stash->{building_info}{$next_type->building_type_id}));
		#Carp::carp("Resource needs:".Dumper(%this_type));		
	}
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
		$c->detach('create');
	}
	
	if ( $c->stash->{party}->turns < $c->config->{garrison_creation_turn_cost} ) {
		$c->stash->{error} = "You need at least " . $c->config->{garrison_creation_turn_cost} . " to create a garrison";
		$c->detach('create');		
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
		$c->detach('create');
	}
	
	my @chars_left_in_party = @{ set(keys %chars_by_id) - set(@char_ids_to_garrison) };
	if ((grep { ! $chars_by_id{$_}->is_dead } @chars_left_in_party) <= 0 ) {
		$c->stash->{error} = "You must have at least one living character in your party";
		$c->detach('create');		
	}
	
	my $garrison = $c->model('DBIC::Garrison')->create(
		{
			land_id => $c->stash->{party_location}->land_id,
			party_id => $c->stash->{party}->id,
			creature_attack_mode => 'Attack Weaker Opponents',
			party_attack_mode => 'Defensive Only',
			name => $c->req->param('name') || undef,
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
	
	$c->res->redirect( $c->config->{url_root} . 'garrison/manage?garrison_id=' . $garrison->id );
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
		$c->detach( 'manage' );
	}
	
	my @chars_left_in_party = @{ set(keys %chars_by_id) - set(keys %char_ids_to_garrison) };
	if ((grep { ! $chars_by_id{$_}->is_dead } @chars_left_in_party) <= 0 ) {
		$c->stash->{error} = "You must have at least one living character in your party";
		$c->detach('manage');		
	}	

	if (scalar @chars_left_in_party > $c->config->{max_party_characters}) {
		$c->stash->{error} = "You can't have more than " . $c->config->{max_party_characters} . " characters in your party";
		$c->detach( 'manage' );
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
	
	$c->res->redirect( $c->config->{url_root} . 'garrison/manage?garrison_id=' . $c->stash->{garrison}->id );
	
}

sub remove : Local {
	my ($self, $c) = @_;
	
	confess "Can't find garrison" unless $c->stash->{garrison};
	
	my @garrison_characters = $c->stash->{garrison}->characters;
	my @characters = $c->stash->{party}->characters_in_party;

	if (scalar @garrison_characters + scalar @characters > $c->config->{max_party_characters}) {
		$c->stash->{error} = "You can't remove this garrison - " .
			"adding these characters would give you more than " . $c->config->{max_party_characters} . " characters in the party";
		$c->detach( 'manage' );
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

		$c->stash->{garrison}->land_id(undef);
		$c->stash->{garrison}->update;
		
		$c->stash->{panel_messages} = ['Garrison Removed'];
		
		$c->forward('/party/main');
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
	$c->stash->{garrison}->update;
	
	$c->res->redirect( $c->config->{url_root} . 'garrison/manage?garrison_id=' . $c->stash->{garrison}->id . '&selected=orders' );
}

sub messages_tab : Local {
	my ($self, $c) = @_;

    my @messages = $c->model('DBIC::Garrison_Messages')->search(
        { 'garrison_id' => $c->stash->{garrison}->id, },
        {
            order_by => 'day.date_started desc',
            prefetch => 'day',
            rows     => 7,                         # TODO: config me
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

sub get_garrison_buildings : Local {
	my ($self, $c, $garrison_id) = @_;
	return $c->model('DBIC::Building')->search(
        	{ 
	        	'owner_id' => $garrison_id,
	        	'owner_type' => 'garrison'
	        },
	        {
	            order_by => 'labor_needed'
	        },
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

sub buildings_tab : Local {
	my ($self, $c) = @_;

	# Create the available_resources/tools hashes for each type.
	my (%available_resources, %available_tools);
	foreach my $next_resource (@{$c->stash->{resource_and_tools}}) {
		if ($next_resource->item_category_id == $c->stash->{resource_category}->item_category_id) {
			$available_resources{$next_resource->item_type} = 0;
		} else {
			$available_tools{$next_resource->item_type} = 0;
		}
	}
	
	#  Get a list of the currently built (or under construction) buildings.
	my @existing_buildings = $self->get_garrison_buildings($c, $c->stash->{garrison}->id);
	my %buildings_by_class;
	foreach my $next_item (@existing_buildings) {
		my $this_type = $c->stash->{building_info}{$next_item->building_type_id};
		$next_item->set_class($this_type->{class});
		$next_item->set_level($this_type->{level});
		$next_item->set_image($this_type->{image});
		$buildings_by_class{$this_type->{class}} = \$next_item;
	}
	
	#  Find which buildings have not been built, and get their lowest level for inclusion in the 'available buildings'.
	my @available_buildings;
	my %existing_classes_seen;
	my %available_upgrades;
	foreach my $next_key (keys %{$c->stash->{building_info}}) {
		my $next_type = \%{$c->stash->{building_info}{$next_key}};
		my $next_class = $next_type->{class};
		
		#  If the class of this building is not an existing building, and it's level is lower than others that we've
		#   seen for this class, remember it.
		
		if (!exists($buildings_by_class{$next_class})) {
			if (!exists($existing_classes_seen{$next_class}) || $existing_classes_seen{$next_class}->{level} > $next_type->{level}) {
				$existing_classes_seen{$next_class} = $next_type;
			}
			
		# Else the building exists - check to see if this is the next upgrade for that building (or the type itself)
		} else {
			my $existing_building = $buildings_by_class{$next_class};
			if (${$existing_building}->level == $next_type->{level} - 1) {
				${$existing_building}->set_upgrades_to($next_type);
			} elsif (${$existing_building}->level == $next_type->{level}) {
				${$existing_building}->set_type($next_type);
			}
		}
	}
	
	#  Construct the available buildings array from the lowest level building classes that haven't been built yet.
	foreach my $next_class_key (keys %existing_classes_seen) {
		push(@available_buildings, $existing_classes_seen{$next_class_key});
	}

	#  Create the list of equipment (resources and tools) owned by the current party.
	my @party_equipment = $self->get_owned_equipment($c, $c->stash->{party}->id, $c->stash->{garrison}->id);
	foreach my $next_item (@party_equipment) {
		if ($next_item->item_type->item_category_id == $c->stash->{resource_category}->item_category_id) {
			$available_resources{$next_item->item_type->item_type}++;
		}
	}
	my %available_items;
	$available_items{'resources'} = \%available_resources;
	$available_items{'tools'} = \%available_tools;
		
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'garrison/buildings.html',
                params   => {
                    #garrison => $c->stash->{garrison},
                    available_buildings => \@available_buildings,
                    available_items => \%available_items,
                    existing_buildings => \@existing_buildings,
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

sub change_gold : Local {
	my ($self, $c) = @_;
	
	my $editable = $c->stash->{party_location}->id == $c->stash->{garrison}->land->id;
	
	return unless $editable;
	
	my $party = $c->stash->{party};
	my $garrison = $c->stash->{garrison};
		
	my $garrison_gold = $c->req->param('garrison_gold');
	my $total_gold = $garrison->gold + $party->gold;
	if ($garrison_gold > $total_gold) {
		$garrison_gold = $total_gold
	}
	
	$garrison_gold = 0 if $garrison_gold < 0;
	
	my $party_gold = $total_gold - $garrison_gold;
	
	$party->gold($party_gold);
	$party->update;
	
	$garrison->gold($garrison_gold);
	$garrison->update;
	
	$c->res->body(
		to_json(
			{
				party_gold => $party_gold,
				garrison_gold => $garrison_gold,
			}
		),
	);
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