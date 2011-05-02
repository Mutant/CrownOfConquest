package RPG::C::Building;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use Data::Dumper;

use JSON;
use POSIX;
use List::Util qw(shuffle);
use Set::Object qw(set);

my %available_resources;
my %available_tools;
my $num_available_tools;

sub auto : Private {
	my ($self, $c) = @_;
	
	return 1;	
}

# get_building_info
#   Constructs the available_resources / available_tools hashes for all defined buildings.  Reads the building definitions
#    from the database, and the tool equipment from the currently cached party.
sub get_building_info {
	my ($self, $c) = @_;

	#  Get the resource and tool category id.
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

	#  Get the list of equipment (resources and tools) owned by the current party.
	my @party_equipment = $c->stash->{party}->get_equipment(qw(Tool Resource));
	foreach my $next_resource (@{$c->stash->{resource_and_tools}}) {
		if ($next_resource->item_category_id == $c->stash->{resource_category}->item_category_id) {
			$available_resources{$next_resource->item_type} = 0;
		} else {
			$available_tools{$next_resource->item_type} = {'tool' => $next_resource, 'count' => 0};
		}
	}

	my @characters = $c->stash->{party}->characters_in_party;
	$available_resources{labor_available} = 0;
	$available_resources{laborers_available} = 0;
	foreach my $next_character (@characters) {
		if (!$next_character->is_dead) {
			$available_resources{labor_available} += getCharacterMultiplier($next_character);
			$available_resources{laborers_available}++;
		}
	}

	$num_available_tools = 0;
	foreach my $next_item (@party_equipment) {
		if ($next_item->item_type->item_category_id == $c->stash->{resource_category}->item_category_id) {
			my $quantity = $next_item->variable('Quantity') // 1;
			$available_resources{$next_item->item_type->item_type} += $quantity;
		} elsif ($next_item->item_type->item_category_id == $c->stash->{tool_category}->item_category_id) {
			$available_resources{labor_available} += getToolMultiplier($next_item);
			$available_tools{$next_item->item_type->item_type}{count}++;
			$num_available_tools++;
		}
	}
	
	#  Gather information on each building type into an array of hashes.
	foreach my $next_type (@{$c->stash->{building_types}}) {
		my %this_type = ('name' => $next_type->name, 'image' => $next_type->image, 'defense' => $next_type->defense_factor+0,
		  'attack' => $next_type->attack_factor+0,  'heal' => $next_type->heal_factor+0,  'commerce' => $next_type->commerce_factor+0,
		  'labor_needed' => $next_type->labor_needed, 'turns_needed' => 0,
		  'raze_labor_needed' => $next_type->labor_to_raze, 'raze_turns_needed' => 0,
		  'building_type_id' => $next_type->building_type_id, 'class' => $next_type->class, 'level' => $next_type->level,
		  'building_schema' => $next_type);
		
		$c->stash->{building_info}{$next_type->building_type_id} = \%this_type;	
	}
}

# calc_needs_by_party
#   Calculates the building needs for the currently cached party.  Fills the necessary values in the given 'building_info'
#    hash, which was created by 'get_building_info'.
sub calc_needs_by_party {
	my ($self, $c, $building_info) = @_;

	my $building_schema = $building_info->{'building_schema'};
	my ($adj_labor, $adj_res) = $self->optimize_tool_usage($building_schema, $available_resources{laborers_available},
	 $num_available_tools);
	#Carp::carp("Building ".$building_schema->name . " returned labor:".$adj_labor.", returned resources:\n".Dumper($adj_res));
	
	my @resource_needs;
	if ($building_schema->clay_needed > 0) {
		push(@resource_needs, {'res_name', 'Clay', 'amount', $adj_res->{'Clay'}, 'image',
			$c->stash->{resource_images}{'Clay'}});
	}
	if ($building_schema->iron_needed > 0) {
		push(@resource_needs, {'res_name', 'Iron', 'amount', $adj_res->{'Iron'}, 'image',
			$c->stash->{resource_images}{'Iron'}});
	}
	if ($building_schema->stone_needed > 0) {
		push(@resource_needs, {'res_name', 'Stone', 'amount', $adj_res->{'Stone'}, 'image',
			$c->stash->{resource_images}{'Stone'}});
	}
	if ($building_schema->wood_needed > 0) {
		push(@resource_needs, {'res_name', 'Wood', 'amount', $adj_res->{'Wood'}, 'image',
			$c->stash->{resource_images}{'Wood'}});
	}

	$building_info->{'turns_needed'} = $available_resources{'labor_available'} != 0
	 ? ceil($building_info->{'labor_needed'} / $available_resources{'labor_available'}) : 1000000;
	if ($building_info->{'turns_needed'} <= 0) { $building_info->{'turns_needed'} = 1; }
	
	$building_info->{'enough_turns'} = ($c->stash->{party}->turns > $building_info->{'turns_needed'}) ? 1 : 0;
	
	$building_info->{'raze_turns_needed'} = $available_resources{'labor_available'} != 0
	 ? ceil($building_info->{'raze_labor_needed'} / $available_resources{'labor_available'}) : 1000000;
	if ($building_info->{'raze_turns_needed'} <= 0) { $building_info->{'raze_turns_needed'} = 1; }
			 		
	#  See if the party has the resources to build/upgrade this type.
	$building_info->{'enough_resources'} = 1;
	foreach my $next_res (@resource_needs) {
		if ($available_resources{$next_res->{res_name}} < $next_res->{amount}) {
			$building_info->{'enough_resources'} = 0;
		}
	}
	$building_info->{'resources_needed'} = \@resource_needs;	
}

# optimize_tool_usage
#   Given a party context (tools, num laborers), determines the best set of tools to use to construct/upgrade
#    the given building.  Does the following:
#      IF enough laborers for all given tools THEN
#         calculates effects using all tools
#      ELSE
#         FOR all laborers
#            score all tools (based on resource and labor savings)
#            sort scored tools
#            pick the best tool
#         END FOR
#      END IF
#    This algorithm ensures that the best tools are used by rescoring each remaining tool, which takes into
#     account any previous effects.  For example, if a previous tool ensures that most Iron is saved, then the
#     next round of scoring sees that and may be a different tool as the next best based on the newly reduced requirements.
#     A bit slower, but better results - however, should only be called on buildings where we really want this info.
sub optimize_tool_usage {
	my ($self, $building, $num_laborers, $num_tools, $res_needed) = @_;

	#  If there are more laborers than tools, then we use all the tools, so calculate effects.
	my $labor_avail = $num_laborers;
	my %resources = ('Wood' => $building->wood_needed, 'Clay' => $building->clay_needed, 'Iron' => $building->iron_needed,
		'Stone' => $building->stone_needed );
	
	#Carp::carp("Optimize tool usage on ".$building->name.", orig labor available:".$labor_avail.", num laborers:".$num_laborers.", num tools:".$num_tools);
	#Carp::carp("Original resources needed:\n".Dumper(\%resources));
	my $score;
	if ($num_laborers >= $num_tools) {
		#Carp::carp("Using all available tools");
		foreach my $next_tool (keys %available_tools) {
			$score = $self->calc_tool_effects(\$labor_avail, \%resources, $available_tools{$next_tool}{tool},
			 $available_tools{$next_tool}{count});
			#Carp::carp("Next tool:".$next_tool.", avail count:".$available_tools{$next_tool}{count}.
			# ", available labor:".$labor_avail.", score:".$score);
		}
	} else {
		#Carp::carp("SCORING METHOD on num_tools:".$num_tools);
		my %current_resources = %resources;			# Cumulative resource needs based on chosen tool bonuses.

		# Make a copy of the available tools, it contains counts, will be decremented as tools are chosen.
		my %our_tools;
		foreach my $next_tool (keys %available_tools) {
			$our_tools{$next_tool}{tool} = $available_tools{$next_tool}{tool};
			$our_tools{$next_tool}{count} = $available_tools{$next_tool}{count};
		}
		
		#  Here is the meat of the algorithm.  For each laborer, find the best available tool.  That is done by scoring
		#   each remaining tool and picking the highest scored tool.  Thus, each pass takes into account the effects of
		#   the previous choice - e.g. if a tool reduces a resource need, the next tool scoring will take that into account.
		for (my $i=0; $i<$num_laborers; $i++){
			my %scored_tools;
			my $num_tools_considered = 0;
			foreach my $next_tool (keys %our_tools) {
				if ($our_tools{$next_tool}{count} <= 0) {		# Any more of this tool type left?
					next;
				}
				my %resource_result = %current_resources;
				my $this_avail_labor = $labor_avail;
				my $score = $self->calc_tool_effects(\$this_avail_labor, \%resource_result, $our_tools{$next_tool}{tool}, 1);

				$scored_tools{$next_tool}{score} = $score;
				%{$scored_tools{$next_tool}{resource_result}} = %resource_result;
				$scored_tools{$next_tool}{adjusted_labor} = $this_avail_labor;
				$num_tools_considered++;
			}
			if ($num_tools_considered <= 0) {	# For safety, shouldn't happen.
				last;
			}

			#  Sort tools by score.			
			my @sorted_tools = sort { $scored_tools{$b}{score} <=> $scored_tools{$a}{score} } keys %scored_tools;

			#  Use the tool with the best score.
			#Carp::carp("Best score on tool:".$sorted_tools[0].", score was:".$scored_tools{$sorted_tools[0]}{score});
			%current_resources = %{$scored_tools{$sorted_tools[0]}{resource_result}};	# Remember the new resource needs.
			$labor_avail = $scored_tools{$sorted_tools[0]}{adjusted_labor};				# Remember the adjusted labor.
			$our_tools{$sorted_tools[0]}{count}--;										# Decrement the chosen tool.
		}
		%resources = %current_resources;
	}
	
	#  Round all fractional resource needs up (TODO: is there an idiom that's better than the foreach?)
	foreach my $res_name (keys %resources) {
		$resources{$res_name} = ceil($resources{$res_name});
	}
	return (ceil($labor_avail), \%resources);
}

# calc_tool_effects
#  Calculates the effects of a given tool on a given set of labor and resource needs.  Returns a numeric score that takes
#   into account the resources and labor saved if this tool were used.  The score is essentially a combined sum of the fractional
#   resources and labor points saved by the given tool on the given labor and resource needs.
sub calc_tool_effects {
	my ($self, $labor_avail, $resources, $tool, $count) = @_;

	#  Check for any effects on any of the resource types.
	my $score = 0;
	foreach ('Wood', 'Stone', 'Iron', 'Clay') {
		my $next_attr = $tool->attribute($_ . ' Savings');
		if (defined $next_attr) {
			
			#  Calculate the savings.
			my $adjusted_value = $count * $resources->{$_} * ($next_attr->value / 100.0);

			#  Adjust the resource needed.  Don't allow to fall below zero.
			$resources->{$_} -= $adjusted_value;
			if ($resources->{$_} < 0) {
				$adjusted_value += $resources->{$_};	# Decrease adjusted value for use in scoring - not all was used.
				$resources->{$_} = 0;
			}
			
			#  Arbitrarily score this as the amount saved.  Favors higher savings of resources.
			$score += $adjusted_value;
			#Carp::carp($_." scores: ".$score.", adj value:".$adjusted_value.", current res:".$resources->{$_}.", count:".$count.", attr value:".$next_attr->value);
		}
	}

	#  If the tool has a labor factor, adjust for it.
	my $labor_attr = $tool->attribute('Build Factor');
	if (defined $labor_attr) {
		my $adjusted_labor = ($labor_attr->value - 1.0);
		${$labor_avail} += $adjusted_labor;
		$score += $adjusted_labor;
	}

	return $score;
}

sub create : Local {
	my ($self, $c) = @_;
	
	$self->get_building_info($c);

	#  Get a list of the currently built (or under construction) buildings.
	my @existing_buildings = $c->model('DBIC::Building')->search(
        	{
        		'land_id' => $c->stash->{party_location}->id,
	        	'owner_id' => $c->stash->{party}->id,
	        	'owner_type' => 'party'
	        },
	        {
	            order_by => 'labor_needed'
	        },
	);
	
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
				$self->calc_needs_by_party($c, $next_type);
				${$existing_building}->set_upgrades_to($next_type);
			} elsif (${$existing_building}->level == $next_type->{level}) {
				${$existing_building}->set_type($next_type);
			}
		}
	}
	
	#  Construct the available buildings array from the lowest level building classes that haven't been built yet.
	foreach my $next_class_key (keys %existing_classes_seen) {
		$self->calc_needs_by_party($c, $existing_classes_seen{$next_class_key});
		push(@available_buildings, $existing_classes_seen{$next_class_key});
	}

	my %available_items;
	$available_items{'resources'} = \%available_resources;
	$available_items{'tools'} = \%available_tools;
		
	$c->forward('RPG::V::TT',
        [{
            template => 'building/create.html',
            params => {
            	party => $c->stash->{party},
				available_buildings => \@available_buildings,
				available_items => \%available_items,
				existing_buildings => \@existing_buildings,
            },
        }]
    );			
}

#  getToolMultiplier - this function returns the multiplying effect on construction of a given tool (default=1).
sub getToolMultiplier : Local {
	my ($self, $item) = @_;
	return 1;
}

#  getCharacterMultiplier - this function returns the multiplying effect on construction of a given character (default=1).
sub getCharacterMultiplier : Local {
	my ($self, $item) = @_;
	return 1;
}
	
sub add : Local {
	my ($self, $c) = @_;

	#  Was a building type id supplied?
	my $building_id = $c->req->param('building_id');
	if (!defined $building_id) {
		croak "You must select a building to create or upgrade";
	}

	#  Check party level.
	if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
		croak "You can't create a building - your party level is too low";
	}

	#  Get info on this building type.
	$self->get_building_info($c);
	my $building_type = \$c->stash->{building_info}{$building_id};
	
	#  Make sure the party has enough turns to build.
	if ( $c->stash->{party}->turns < ${$building_type}->{turns_needed} ) {
		$c->stash->{error} = "Your party needs at least " . ${$building_type}->{turns_needed} . " turns to create this building";
		$c->detach('create');		
	}

	#  Create the building.
	my $building = $c->model('DBIC::Building')->create(
		{
			land_id => $c->stash->{party_location}->land_id,
			building_type_id => $building_id,
			owner_id => $c->stash->{party}->id,
			owner_type => "party",
			name => ${$building_type}->{name},
			
			#  For now, partial construction not allowed, so we use all the materials up front
			'clay_needed' => 0,
			'stone_needed' => 0,
			'wood_needed' => 0,
			'iron_needed' => 0,
			'labor_needed' => 0,
		}
	);
	
	
	
	#  If this is an upgrade, then find the previous building and delete it.
	my @pre_upgrade = $c->model('DBIC::Building')->search(
		{
			'land_id' => $c->stash->{party_location}->id,
			'building_type.class' => ${$building_type}->{class},
			'building_type.level' => ${$building_type}->{level}-1,
		},
		{
			'join' => 'building_type',
		},
	);

	foreach my $pre_building (@pre_upgrade) {
	    $pre_building->unclaim_land;
		$pre_building->delete;
	}
	
	$c->forward('change_building_ownership', [$building]);

	#  Make sure the party has the necessary resources.  If so, consume them.
	#  Debug - if free buildings, don't deduct resources.
	if (!defined RPG->config->{dbg_free_buildings} || RPG->config->{dbg_free_buildings} != 1) {
		my @resources_needed;
		foreach my $next_res (@{${$building_type}->{resources_needed}}) {
			push(@resources_needed, $next_res->{res_name});
			push(@resources_needed, $next_res->{amount});
		}
		if (!($c->stash->{party}->consume_items('Resource', @resources_needed))) {
			$c->stash->{error} = "Your party does not have the resources needed to create this building";
			$c->detach('create');			
		}
	}
	
	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We created a " . ${$building_type}->{name} . " at " . $c->stash->{party}->location->x . ", "
			 . $c->stash->{party}->location->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);

	$c->stash->{party}->turns($c->stash->{party}->turns - ${$building_type}->{turns_needed});
	$c->stash->{party}->update;
	
	my $message = $c->forward( '/quest/check_action', [ 'constructed_building', $building ] );
	$c->flash->{messages} = $message if @$message;

	$c->res->redirect( $c->config->{url_root} );
}

sub seize : Local {
	my ($self, $c) = @_;

	#  Check party level.
	if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
		croak "You can't seize building - your party level is too low";
	}

	#   Grab the building list, report on each on seized.
	my @existing_buildings = $c->model('DBIC::Building')->search(
        	{ 'land_id' => $c->stash->{party_location}->id, },
        	{ },
	);
	my $count = 0; my ($owner_id, $owner_type);
	my $sep = ""; my $building_names = "";
	foreach my $next_building (@existing_buildings) {

		#  Make sure this building is indeed owned by another party.
		if ($c->stash->{party}->id == $next_building->owner_id && $next_building->owner_type eq 'party') {
			croak "You cannot seize your own " . $next_building->name . " at " .
			 $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y;		
		}
		$count++;
		$building_names .= $sep . $next_building->name;
		$owner_id = $next_building->owner_id;			# Assume all have same owner.
		$owner_type = $next_building->owner_type;
		
		$c->forward('change_building_ownership', [$next_building]);
	}

	#  Give the former owner the unfortunate news.
	my $message = "Our building at " .
    			 $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y .
    			 " was seized from us by " . $c->stash->{party}->name;
	if ($owner_type eq 'party') {
    	$c->model('DBIC::Party_Messages')->create(
    		{
    			message => $message,
    			alert_party => 1,
    			party_id => $owner_id,
    			day_id => $c->stash->{today}->id,
    		}
        );
	}
	elsif ($owner_type eq 'kingdom') {
	   $c->model('DBIC::Kingdom_Messages')->create(
	       {
	           kingdom_id => $owner_id,
	           day_id => $c->stash->{today}->id,
	           message => $message,
	       }
	   );
	   
	   
        # If they party seized a building belonging to their kingdom, reduce loyalty
        if ($owner_id == $c->stash->{party}->kingdom_id) {	   
            my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
                {
                    kingdom_id => $c->stash->{party}->kingdom_id,
                    party_id => $c->stash->{party}->id,
                }           
            );
            
            $party_kingdom->decrease_loyalty(7);
            $party_kingdom->update;
        }	   
	   
	}

	#  But crow about it to ourselves.
	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We seized the " . $building_names . " at " .
			 $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
		);

	#  Update the ownership of all buildings in this sector.
	$c->model('DBIC::Building')->search(
        	{ 'land_id' => $c->stash->{party_location}->id, },
        	{ },
	)->update
	(
			{ owner_id => $c->stash->{party}->id,
			owner_type => "party", },
	);
	
	$c->stash->{panel_messages} = [$count . ' building' . ($count==1?'':'s') . ' seized!'];
		
	$c->forward('/party/main');
}

sub raze : Local {
	my ($self, $c) = @_;

	#  Check party level.
	if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
		croak "You can't raze building - your party level is too low";
	}

	$self->get_building_info($c);
	my @existing_buildings = $c->model('DBIC::Building')->search(
        	{ 'land_id' => $c->stash->{party_location}->id, }, { },
	);

	#  Figure how many turns are needed to raze the buildings here.
	my $raze_turns_needed = 0;
	foreach my $next_building (@existing_buildings) {
		my $next_type = \%{$c->stash->{building_info}{$next_building->building_type_id}};
		if ($next_type->{raze_turns_needed} > $raze_turns_needed) {
			$raze_turns_needed = $next_type->{raze_turns_needed};
		}
	}
	
	#  Make sure the party has enough turns to raze.
	my $count = @existing_buildings;
	if ( $c->stash->{party}->turns < $raze_turns_needed) {
		croak "Your party needs at least " . $raze_turns_needed . " turns to raze " .
		 ($count > 1 ? "this building" : "these buildings");
	}

	#  Delete the buildings.  Assume all are owned by the same player (could be us).
	my ($owner_id, $owner_type);
	my $sep = ""; my $building_names = "";
	foreach my $next_building (@existing_buildings) {
		$owner_id = $next_building->owner_id;
		$owner_type = $next_building->owner_type;
		$building_names .= $sep . $next_building->name;
		$sep = ", ";
		$next_building->unclaim_land;
		$next_building->delete;
	}

	#  If we don't own this building, give the former owner the bad news.
	my $message = "Our building at " .
				 $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y .
				 " was razed by " . $c->stash->{party}->name;
	if ($c->stash->{party}->id != $owner_id && $owner_type eq 'party') {
		$c->model('DBIC::Party_Messages')->create(
			{
				message => $message,
				alert_party => 1,
				party_id => $owner_id,
				day_id => $c->stash->{today}->id,
			}
		);
	}
	elsif ($owner_type eq 'kingdom') {
		$c->model('DBIC::Kingdom_Messages')->create(
			{
				message => $message,
				kingdom_id => $owner_id,
				day_id => $c->stash->{today}->id,
			}
		);	    
		
        # If the party razed a building belonging to their kingdom, reduce loyalty
        if ($owner_id == $c->stash->{party}->kingdom_id) {	   
            my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
                {
                    kingdom_id => $c->stash->{party}->kingdom_id,
                    party_id => $c->stash->{party}->id,
                }           
            );
            
            $party_kingdom->decrease_loyalty(10);
            $party_kingdom->update;
        }	 		
		  
	}
	
	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We razed the " . $building_names . " at " .
			 $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);

	$c->flash->{messages} = [$count . ' building' . ($count==1?'':'s') . ' razed!'];
		
	$c->stash->{party}->turns($c->stash->{party}->turns - $raze_turns_needed);
	$c->stash->{party}->update;

    $c->res->redirect( $c->config->{url_root} . '/party/main' );
}

sub cede : Local {
    my ($self, $c) = @_;
    
    croak "You don't have a Kingdom" unless $c->stash->{party}->kingdom_id;
    
	my @existing_buildings = $c->model('DBIC::Building')->search(
        { 'land_id' => $c->stash->{party_location}->id, },
	);
	
	my @messages;
	foreach my $building (@existing_buildings) {
	   next unless $building->owner_type eq 'party' and $building->owner_id == $c->stash->{party}->id;
	   $building->owner_type('kingdom');
	   $building->owner_id($c->stash->{party}->kingdom_id);
	   $building->update;
	   
	   $c->forward('change_building_ownership', [$building]);
	   
	   	my $message = $c->forward( '/quest/check_action', [ 'ceded_building', $building ] );
	   	push @messages, @$message if @$message;
	   	
	   	$c->stash->{party}->kingdom->add_to_messages(
	   	   {
	   	       day_id => $c->stash->{today}->id,
	   	       message => "The party " . $c->stash->{party}->name . " ceded a building to the kingdom at " 
	   	           . $c->stash->{party_location}->x . ', ' . $c->stash->{party_location}->y,
	   	   }
	   	); 
	   
	    # Increase loyalty
        my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
            {
                kingdom_id => $c->stash->{party}->kingdom_id,
                party_id => $c->stash->{party}->id,
            }           
        );
        
        $party_kingdom->increase_loyalty(7);
        $party_kingdom->update;
	}
	
	my $count = scalar @existing_buildings;
	push @messages, $count . ' building' . ($count==1?'':'s') . ' ceded to the Kingdom of ' . $c->stash->{party}->kingdom->name;
	$c->flash->{messages} = \@messages;
	
	$c->res->redirect( $c->config->{url_root} . '/party/main' );
       
}

sub change_building_ownership : Private {
    my ($self, $c, $building) = @_;
    
    $building->unclaim_land;
    $building->claim_land;
}

1;