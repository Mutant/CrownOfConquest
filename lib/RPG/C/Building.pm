package RPG::C::Building;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use Data::Dumper;

use List::Util qw(shuffle);

sub auto : Private {
    my ($self, $c) = @_;
    
    if ($c->stash->{party}->in_combat) {
        croak "Can't manage buildings while in combat";   
    }
    
    return 1;
}

sub get_party_resources {
    my ($self, $c) = @_;
    
	#  Get the list of resources owned by the current party.
	my %resources;
	
	my @party_equipment = $c->stash->{party}->get_equipment(qw(Resource));
	foreach my $resource (@party_equipment) {
        $resources{$resource->item_type->item_type} += $resource->variable('Quantity') // 0;	
	}
	
	return %resources;    
}

sub construct : Local {
    my ($self, $c) = @_;
   
    my $building_type = $c->model('DBIC::Building_Type')->find(
        {
            level => 1,
        }
    );
    
    my %party_resources = $self->get_party_resources($c);
    
    my %resources = map { $_->item_type => $_ } $c->model('DBIC::Item_Type')->search(
        {
            'category.item_category' => 'Resource',
        },
        {
            join => 'category',
        }
    ); 
    	
	$c->forward('RPG::V::TT',
        [{
            template => 'building/construct.html',
            params => {
            	party => $c->stash->{party},
                building_type => $building_type,
                party_resources => \%party_resources,
                enough_resources => $building_type->enough_resources(%party_resources),
                resources => \%resources,
            },
        }]
    );    
}

sub build : Local {
    my ($self, $c) = @_; 
    
	my @current_building = $c->stash->{party_location}->building;
    if (@current_building) {
        $c->stash->{error} = "There's already a building in this sector!";
        $c->detach('/panel/refresh');
    }   
    
    my $building_type = $c->model('DBIC::Building_Type')->find(
        {
            level => 1,
        }
    );

    if (! $building_type->enough_turns($c->stash->{party})) {
        $c->stash->{error} = "You don't have enough turns to construct the building";
        $c->detach('/panel/refresh');
    }
   
	my %resources_needed = (
       'Clay'  => $building_type->clay_needed,
       'Iron'  => $building_type->iron_needed,
       'Wood'  => $building_type->wood_needed,
       'Stone' => $building_type->stone_needed,
	);
	if (! $c->stash->{party}->consume_items('Resource', %resources_needed) ) {
		$c->stash->{error} = "Your party does not have the resources needed to create this building";
		$c->detach('/panel/refresh');			
	}    
    
	#  Create the building.
	my $building = $c->model('DBIC::Building')->create(
		{
			land_id => $c->stash->{party_location}->land_id,
			building_type_id => $building_type->id,
			owner_id => $c->stash->{party}->id,
			owner_type => "party",
			name => $building_type->name,
			
			#  For now, partial construction not allowed, so we use all the materials up front
			'clay_needed' => 0,
			'stone_needed' => 0,
			'wood_needed' => 0,
			'iron_needed' => 0,
			'labor_needed' => 0,
		}
	);   
	
	$c->forward('change_building_ownership', [$building]);

	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We created a " . $building_type->name . " at " . $c->stash->{party}->location->x . ", "
			 . $c->stash->{party}->location->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);

	$c->stash->{party}->turns($c->stash->{party}->turns - $building_type->turns_needed($c->stash->{party}));
	$c->stash->{party}->update;
	
	my $message = $c->forward( '/quest/check_action', [ 'constructed_building', $building ] );
	
	push @$message, "Building created";
	
	$c->stash->{panel_messages} = $message if @$message;
		
	$c->forward('/map/refresh_current_loc');
	
	$c->forward( '/panel/refresh', [[screen => 'close'], 'party_status', 'messages'] );
}

sub manage : Local {
    my ($self, $c) = @_;
    
	#  Get a list of the currently built (or under construction) buildings owned by the party.
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
	
	croak "No buildings to upgrade\n" unless @existing_buildings;
	
	my ($building) = @existing_buildings;
	
	my $building_type = $building->building_type;
	
	my $upgradable_to_type = $c->model('DBIC::Building_Type')->find(
	   {
	       level => $building_type->level + 1,
	   }
	);
	
    my %party_resources = $self->get_party_resources($c);
    
    my %resources = map { $_->item_type => $_ } $c->model('DBIC::Item_Type')->search(
        {
            'category.item_category' => 'Resource',
        },
        {
            join => 'category',
        }
    );	

	$c->forward('RPG::V::TT',
        [{
            template => 'building/manage.html',
            params => {
            	party => $c->stash->{party},
                building_type => $building_type,
                upgradable_to_type => $upgradable_to_type,
                party_resources => \%party_resources,
                enough_resources => $upgradable_to_type->enough_resources(%party_resources),
                resources => \%resources,
            },
        }]
    );     
}

sub upgrade : Local {
    my ($self, $c) = @_;
    
	#  Get a list of the currently built (or under construction) buildings owned by the party.
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
	
	croak "No buildings to upgrade\n" unless @existing_buildings;
	
	my ($building) = @existing_buildings;
	
	my $building_type = $building->building_type;
	
	my $upgradable_to_type = $c->model('DBIC::Building_Type')->find(
	   {
	       level => $building_type->level + 1,
	   }
	);
	
	croak "Building can't be upgraded\n" unless $upgradable_to_type;	
	
    if (! $upgradable_to_type->enough_turns($c->stash->{party})) {
        $c->stash->{error} = "You don't have enough turns to upgrade the building";
        $c->detach('/panel/refresh');
    }	
	
	my %resources_needed = (
       'Clay'  => $upgradable_to_type->clay_needed,
       'Iron'  => $upgradable_to_type->iron_needed,
       'Wood'  => $upgradable_to_type->wood_needed,
       'Stone' => $upgradable_to_type->stone_needed,
	);
	
	if (! $c->stash->{party}->consume_items('Resource', %resources_needed) ) {
		$c->stash->{error} = "Your party does not have the resources needed to upgrade this building";
		$c->detach('/panel/refresh');			
	}
	
	$building->building_type_id($upgradable_to_type->id);
	$building->update;
	
	$c->forward('change_building_ownership', [$building]);


	$c->stash->{party}->turns($c->stash->{party}->turns - $building_type->turns_needed($c->stash->{party}));
	$c->stash->{party}->update;
	
	$c->stash->{panel_messages} = ["Building upgraded"];
		
	$c->forward('/map/refresh_current_loc');
	
	$c->forward( '/panel/refresh', [[screen => 'close'], 'party_status', 'messages'] );	
}

sub seize : Local {
	my ($self, $c) = @_;

	#  Check party level.
	if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
		croak "You can't seize building - your party level is too low";
	}
	
	if ( $c->stash->{party_location}->garrison ) {
	   croak "Can't seize a building with a garrison";   
	}	

    if ( $c->stash->{party}->turns < $c->config->{building_seize_turn_cost} ) {
        $c->stash->{error} = "You need at least " . $c->config->{building_seize_turn_cost} . " turns to seize the building";
        $c->detach('/panel/refresh');
    }

	#   Grab the building list, report on each on seized.
	my @existing_buildings = $c->stash->{party_location}->building;	
	my ($building) = @existing_buildings;
	
	croak "No building to seize\n" unless $building;
	
	# Make sure this building is indeed owned by another party.
    if ($c->stash->{party}->id == $building->owner_id && $building->owner_type eq 'party') {
        croak "You cannot seize your own building\n";		
    }
    		
	$c->forward('change_building_ownership', [$building]);

	#  Give the former owner the unfortunate news.
	my $message = "Our building at " . $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y .
    			  " was seized from us by " . $c->stash->{party}->name;
    			  
	if ($building->owner_type eq 'party') {
    	$c->model('DBIC::Party_Messages')->create(
    		{
    			message => $message,
    			alert_party => 1,
    			party_id => $building->owner_id,
    			day_id => $c->stash->{today}->id,
    		}
        );
	}
	elsif ($building->owner_type eq 'kingdom') {
	   $c->model('DBIC::Kingdom_Messages')->create(
	       {
	           kingdom_id => $building->owner_id,
	           day_id => $c->stash->{today}->id,
	           message => $message,
	       }
	   );
	   
	   
        # If they party seized a building belonging to their kingdom, reduce loyalty
        if ($building->owner_id == $c->stash->{party}->kingdom_id) {	   
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
			message => "We seized the " . $building->name . " at " . $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);

	#  Update the ownership building
	$building->owner_id($c->stash->{party}->id);
	$building->owner_type('party');	
	$building->update;
	
	$c->stash->{party}->turns($c->stash->{party}->turns - $c->config->{building_seize_turn_cost} );
	$c->stash->{party}->update;
	
	$c->stash->{panel_messages} = ['Building Seized'];
	
	$c->forward( '/panel/refresh', ['messages', 'party_status'] );
}

sub raze : Local {
	my ($self, $c) = @_;

	#  Check party level.
	if ( $c->stash->{party}->level < $c->config->{minimum_building_level} ) {
		croak "You can't raze building - your party level is too low";
	}
	
	#   Grab the building list, report on each on seized.
	my @existing_buildings = $c->stash->{party_location}->building;	
	my ($building) = @existing_buildings;
	
	croak "No building to raze\n" unless $building;
	
	my $turns_to_raze = $building->building_type->turns_to_raze($c->stash->{party});
		
	#  Make sure the party has enough turns to raze.	
	if ( $c->stash->{party}->turns < $turns_to_raze ) {
	    $c->stash->{error} = "You need at least " . $turns_to_raze . " turns to raze the building";
	    $c->detach('/panel/refresh');
	}
	
	if ( $c->stash->{party_location}->garrison ) {
	   croak "Can't raze a building with a garrison";   
	}

	#  If we don't own this building, give the former owner the bad news.
	my $message = "Our building at " .
				 $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y .
				 " was razed by " . $c->stash->{party}->name;
	if ($c->stash->{party}->id != $building->owner_id && $building->owner_type eq 'party') {
		$c->model('DBIC::Party_Messages')->create(
			{
				message => $message,
				alert_party => 1,
				party_id => $building->owner_id ,
				day_id => $c->stash->{today}->id,
			}
		);
	}
	elsif ($building->owner_type eq 'kingdom') {
		$c->model('DBIC::Kingdom_Messages')->create(
			{
				message => $message,
				kingdom_id => $building->owner_id,
				day_id => $c->stash->{today}->id,
			}
		);	    
		
        # If the party razed a building belonging to their kingdom, reduce loyalty
        if ($building->owner_id == $c->stash->{party}->kingdom_id) {	   
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
			message => "We razed the " . $building->name . " at " . $c->stash->{party}->location->x . ", " . $c->stash->{party}->location->y,
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);
	
	$building->unclaim_land;
	$building->delete;
	

	$c->stash->{panel_messages} = ['Building Razed!'];
		
	$c->stash->{party}->turns($c->stash->{party}->turns - $turns_to_raze);
	$c->stash->{party}->update;
	
	$c->forward('/map/refresh_current_loc');

    $c->forward( '/panel/refresh', [[screen => 'close'], 'messages'] );
}

sub cede : Local {
    my ($self, $c) = @_;
    
    croak "You don't have a Kingdom" unless $c->stash->{party}->kingdom_id;
    
	# Grab the building list
	my @existing_buildings = $c->stash->{party_location}->building;	
	my ($building) = @existing_buildings;
	
	croak "No building to cede\n" unless $building;
	
	if ($building->owner_type ne 'party' or $building->owner_id != $c->stash->{party}->id) {
        croak "Not owner of the building\n"; 
	}
	
	my @messages;

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
	
	push @messages, 'Building ceded to the Kingdom of ' . $c->stash->{party}->kingdom->name;
	$c->stash->{panel_messages} = \@messages;
	
	$c->forward( '/panel/refresh', [[screen => 'close'], 'messages'] );
       
}

sub change_building_ownership : Private {
    my ($self, $c, $building) = @_;
    
    $building->unclaim_land;
    $building->claim_land;
}

1;