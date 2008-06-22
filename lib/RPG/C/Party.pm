package RPG::C::Party;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;

sub main : Local {
	my ($self, $c) = @_;
	
	my $panels = $c->forward('/panel/refresh', ['messages', 'map', 'party']);

    $c->forward('RPG::V::TT',
        [{
            template => 'party/main.html',
			params => {
				party  => $c->stash->{party},
				panels => $panels, 
			},
        }]
    );
}

sub sector_menu : Local {
    my ($self, $c) = @_;
    
	my $creature_group = $c->stash->{creature_group};
    
    $c->forward('RPG::V::TT',
        [{
            template => 'party/sector_menu.html',
			params => {
				creature_group => $creature_group,
				messages => $c->stash->{messages},
			},
			return_output => 1,
        }]
    );
}

sub list : Local {
    my ($self, $c) = @_;	
    
    my $party = $c->stash->{party};

    my @characters = $c->stash->{party}->characters;    
    
    my %spells;
    foreach my $character (@characters) {
    	my %search_criteria = (
    		memorised_today => 1,
    		number_cast_today => \'< memorise_count',
    		character_id => $character->id,
		);		
		
		$party->in_combat_with ? $search_criteria{'spell.combat'} = 1 : $search_criteria{'spell.non_combat'} = 1;
    	
    	my @spells = $c->model('Memorised_Spells')->search(
			\%search_criteria,
    		{
    			prefetch => 'spell',
    		},
    	);
    	
    	$spells{$character->id} = \@spells if @spells;
    }
    
    #warn ref $c->stash->{creature_group};
    
    my @creatures = $c->stash->{creature_group} ? $c->stash->{creature_group}->creatures : ();
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'party/party_list.html',
			params => {
                party => $party,
                characters => \@characters,
                combat_actions => $c->session->{combat_action},
                creatures => \@creatures,
                spells => \%spells,
			},
			return_output => 1,
        }]
    );
}

sub status : Local {
	my ($self, $c) = @_;	
    
    my $party = $c->stash->{party};
	
    $c->forward('RPG::V::TT',
        [{
            template => 'party/status.html',
			params => {
                party => $party,
			},
			return_output => 1,
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
    
    if ($c->config->{new_party_characters} <= $c->model('DBIC::Character')->count( {party_id => $c->session->{party_id}})) {
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
    
    my $character = $c->model('DBIC::Character')->create({
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

sub swap_chars : Local {
	my ($self, $c) = @_;
	
	return if $c->req->param('target') == $c->req->param('moved');
	
	my %characters = map { $_->id => $_ } $c->stash->{party}->characters;
	
	# Moved char moves to the position of the target char
	my $moved_char_destination = $characters{ $c->req->param('target') }->party_order;
	my $moved_char_origin      = $characters{ $c->req->param('moved') }->party_order;
	
	# Is the moved char moving up or down?
	my $moving_up = $characters{ $c->req->param('moved') }->party_order > $moved_char_destination ? 1 : 0;

	# Move the rank separator if necessary.
	# We need to do this before adjusting for drop_pos
	my $sep_pos = $c->stash->{party}->rank_separator_position;
	warn "moving_up: $moving_up, dest: $moved_char_destination, sep_pos: $sep_pos\n";
	if ($moving_up && $moved_char_destination <= $sep_pos) {
		warn "updating sep_pos\n";
		$c->stash->{party}->rank_separator_position($sep_pos+1);
		$c->stash->{party}->update;
	}
	elsif (! $moving_up && $moved_char_destination >= $sep_pos) {
		$c->stash->{party}->rank_separator_position($sep_pos-1);
		$c->stash->{party}->update;
	}

	# If the char was dropped after the destination and we're moving up, the destination is decremented
	$moved_char_destination++ if $moving_up && $c->req->param('drop_pos') eq 'after';

	# If the char was dropped before the destination and we're moving down, the destination is incremented
	$moved_char_destination-- if ! $moving_up && $c->req->param('drop_pos') eq 'before';
	
	# Adjust all the chars' positions	
	foreach my $character (values %characters) {
		if ($character->id == $c->req->param('moved')) {
			$character->party_order($moved_char_destination);	
		}
		elsif ($moving_up) {
			next if $character->party_order < $moved_char_destination ||
				$character->party_order > $moved_char_origin;
				
			$character->party_order($character->party_order+1);
		}
		else {
			next if $character->party_order < $moved_char_origin ||
				$character->party_order > $moved_char_destination;
				
			$character->party_order($character->party_order-1);
		}
		
		$character->update;
	}
	

}

sub move_rank_separator : Local {
	my ($self, $c) = @_;
	
	my $target_char = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('target'),
		},
	);
	
	my $new_pos = $c->req->param('drop_pos') eq 'after' ? $target_char->party_order : $target_char->party_order-1;
	
	# We don't do anything if it's been dragged to the top. the GUI should prevent this from happening.
	return if $new_pos == 0; 
	
	$c->stash->{party}->rank_separator_position($new_pos);
	$c->stash->{party}->update;
}

sub camp : Local {
	my ($self, $c) = @_;
	
	my $party = $c->stash->{party};
	
	if ($party->turns >= RPG->config->{camping_turns}) {
		$party->turns($party->turns - RPG->config->{camping_turns});
		$party->rest($party->rest + 1);
		$party->update;
			
		$c->stash->{messages} = "The party camps for a short period of time";
	}
	else {
		$c->stash->{error} = "You don't have enough turns left today to camp";	
	}
	
	$c->forward('/panel/refresh', ['messages', 'party_status']);
}

1;
