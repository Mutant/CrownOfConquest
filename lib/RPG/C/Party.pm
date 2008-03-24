package RPG::C::Party;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;

sub main : Local {
	my ($self, $c) = @_;

	# TODO: refactor so it can be used by list_characters
    my $party = $c->stash->{party};

    my @characters = $c->stash->{party}->characters;
	
	my $map = $c->forward('/map/view');

	my $bottom_panel;
	
	if ($party->location->town) {
		$bottom_panel = $c->forward('/town/main');
	}
	elsif ($party->in_combat_with) {
		$bottom_panel = $c->forward('/combat/main'); 
	}
	else {	
		# See if party is in same location as a creature
	    # TODO: would be nice to have a way of figuring out if the party just moved here, so we don't have to go
	    #   thru this check for combat if they've been in this sector a while (altho still need to check
	    #   in case creatures have moved into the sector while the party was doing something		
	    my @creatures = $c->model('DBIC::CreatureGroup')->search(
	        {
	            'x' => $party->location->x,
	            'y' => $party->location->y,
	        },
	        {
	            prefetch => [('location', {'creatures' => 'type'})],
	        },
	    );
	
	    # XXX: we should only ever get one creature group from above, since creatures shouldn't move into
	    #  the same square as another group. May pay to check this here and fatal if there are more than one.
	    #  At any rate, we'll just look at the first group.        
	    my $creature_group = shift @creatures;	   
		    
	    # If there are creatures here, check to see if we go straight into a combat
	    if ($creature_group && $creature_group->initiate_combat($party, $c->config->{creature_attack_chance})) {
	        $c->stash->{creature_group} = $creature_group;
			$bottom_panel = $c->forward('/combat/start',
				[{
					creature_group      => $creature_group,
					creatures_initiated => 1,
				}],
			);
    	}		   
	    
	    # Get standard sector menu, plus display create group if present (and combat hasn't yet started)
	    else {
			$bottom_panel = $c->forward('RPG::V::TT',
		        [{
		            template => 'party/sector_menu.html',
					params => {
		                creature_group => $creature_group
					},
					return_output => 1,
		        }]
		    );		    	    	
	    }
	}
	
    $c->forward('RPG::V::TT',
        [{
            template => 'party/main.html',
			params => {
                party => $party,
                map => $map,
                bottom_panel => $bottom_panel,
                characters => \@characters,
                combat_actions => $c->session->{combat_action},
			},
        }]
    );
}

sub create : Local {
    my ($self, $c) = @_;
    
    $c->forward('RPG::V::TT',
        [{
            template => 'party/create.html',
        }]
    );    
}
 
sub list_characters : Local {   
    my ($self, $c) = @_;
    
    my $party = $c->stash->{party};

    my @characters = $party->characters;
        
    $c->forward('RPG::V::TT',
        [{
            template => 'party/add_characters.html',
            params => {            	
                characters => \@characters,
                new_char_allowed => $c->config->{new_party_characters} > scalar @characters,
            },
        }]
    );
}

sub new_character : Local {
    my ($self, $c) = @_;
    
    if ($c->config->{new_party_characters} <= $c->model('Character')->count( {party_id => $c->session->{party_id}})) {
        $c->forward('RPG::V::TT',
            [{
                template => 'party/max_characters.html',
                params => {
                    max_allowed => $c->config->{new_party_characters}
                },
            }]
        )    
    }
    else {    
        $c->forward('RPG::V::TT',
            [{
                template => 'party/new_character.html',
                params => {
                    races => [ $c->model('Race')->all ],
                    classes => [ $c->model('Class')->all ],
                    stats_pool => $c->config->{stats_pool},
                },
                fill_in_form => 1,
            }]
        );    
    }
}

sub create_character : Local {
    my ($self, $c) = @_;

    unless ($c->req->param('name') && $c->req->param('race') && $c->req->param('class')) {
        $c->stash->{error} = 'Please choose a name, race and class';
        $c->detach('/party/new_character');
    }

    my $total_mod_points = 0;
    foreach my $stat (@RPG::M::Character::STATS) {
        $total_mod_points += $c->req->param('mod_' . $stat);
    }

    if ($total_mod_points > $c->config->{stats_pool}) {
        $c->stash->{error} = "You've used more than the total stats pool!";
        $c->detach('/party/new_character');
    }

    my $race = $c->model('Race')->find( $c->req->param('race') );
    
    my $class = $c->model('Class')->find({class_name => $c->req->param('class')});
    
    my $character = $c->model('Character')->create({
        character_name => $c->req->param('name'),
        class_id => $class->id,
        race_id => $c->req->param('race'),
        strength => $race->base_str + $c->req->param('mod_str'),
        intelligence => $race->base_int + $c->req->param('mod_int'),
        agility => $race->base_agl + $c->req->param('mod_agl'),
        divinity => $race->base_div + $c->req->param('mod_div'),
        constitution => $race->base_con + $c->req->param('mod_con'),
        party_id => $c->session->{party_id},
    });
    
    $character->roll_all;

    $c->forward('/party/list_characters');
}

=head2 calculate_values

Calculate hit point, magic point, and faith points (where appropriate) for a particular class

=cut

sub calculate_values : Local {
    my ($self, $c) = @_;

    return unless $c->req->param('class');
    
    my $class = $c->model('Class')->find({class_name => $c->req->param('class')});
    
    my %points = (
        hit_points => RPG::Schema::Character->roll_hit_points($c->req->param('class'), 1, $c->req->param('total_con'))
    );
    
    $points{magic_points} = RPG::Schema::Character->roll_magic_points(1, $c->req->param('total_int'))
        if $class->class_name eq 'Mage';
    
    $points{faith_points} = RPG::Schema::Character->roll_faith_points(1, $c->req->param('total_div'))
        if $class->class_name eq 'Priest';
                
    my $return = jsdump('points', \%points);
    
    $c->res->body($return);
}

sub set_order : Local {
	my ($self, $c) = @_;
	
	my $count = 1;
	
	foreach my $char_id ($c->req->param('order')) {
		my $char = $c->model('DBIC::Character')->find({character_id => $char_id});
		next if $char->party_id != $c->session->{party_id};
	
		$char->party_order($count);
		$char->update;
		$count++;
	}
	
}

1;
