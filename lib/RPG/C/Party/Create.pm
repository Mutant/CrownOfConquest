package RPG::C::Party::Create;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON;
use DateTime;
use List::Util qw(shuffle);

sub auto : Private {
	my ($self, $c) = @_;
	
    unless ($c->stash->{party}) {
    	$c->stash->{party} = $c->model('DBIC::Party')->find_or_create(
    		{
    			player_id => $c->session->{player}->id,
    			turns => $c->config->{daily_turns},
    			gold => $c->config->{start_gold},
    		},
    	)
    }
    
	if ($c->stash->{party}->created) {
		die "Shouldn't be creating a party when you already have one!\n";
	}

	return 1;
}

sub create : Local {
    my ($self, $c) = @_;
    
    my $party = $c->stash->{party};

    my @characters = $party->characters;
   
    $c->forward('RPG::V::TT',
        [{
            template => 'party/create.html',
            params => {
            	player => $c->session->{player},
            	party => $party,
            	characters => \@characters,
                new_char_allowed => $c->config->{new_party_characters} > scalar @characters,
            },
        }]
    );    
}

sub save_party : Local {
	my ($self, $c) = @_;
	
	$c->stash->{party}->name($c->req->param('name'));
	$c->stash->{party}->update;
	
	if ($c->req->param('add_character')) {
		$c->res->redirect($c->config->{url_root} . '/party/create/new_character');	
	}
	else {
		$c->stash->{party}->created(DateTime->now());

		# Find starting town
		my @towns = shuffle $c->model('DBIC::Town')->search(
			{
				prosperity => {'<=', $c->config->{max_starting_prosperity}},
			}
		);

		my $town = shift @towns;
		$c->stash->{party}->land_id($town->land_id);	
	
		$c->stash->{party}->update;
		
		$c->res->redirect($c->config->{url_root} . '/party/create/complete');
	}
}

sub new_character : Local {
    my ($self, $c) = @_;
    
    if ($c->config->{new_party_characters} <= $c->model('DBIC::Character')->count( {party_id => $c->stash->{party}->id})) {
        $c->forward('RPG::V::TT',
            [{
                template => 'party/max_characters.html',
                params => {
                    max_allowed => $c->config->{new_party_characters}
                },
            }]
        );
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
        $c->detach('new_character');
    }
    
    my $char_count = $c->model('DBIC::Character')->count( {party_id => $c->stash->{party}->id} );
    if ($char_count >= $c->config->{new_party_characters}) {
    	$c->stash->{error} = 'You already have ' . $c->config->{new_party_characters} . ' characters in your party';
    	$c->detach('create');
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
        party_id => $c->stash->{party}->id,
        level => 1,
        party_order => $char_count+1,
    });
    
    $character->roll_all;

    $c->res->redirect($c->config->{url_root} . '/party/create');
}

=head2 calculate_values

Calculate hit point, magic point, and faith points (where appropriate) for a particular class

=cut

sub calculate_values : Local {
    my ($self, $c) = @_;
    
    my $return;

	unless ($c->req->param('class') && $c->req->param('total_con') && $c->req->param('total_int') && $c->req->param('total_div')) {
    	$return = to_json {};
	}
	else {    
	    my $class = $c->model('DBIC::Class')->find({class_name => $c->req->param('class')});
	    
	    my %points = (
	        hit_points => RPG::Schema::Character->roll_hit_points($c->req->param('class'), 1, $c->req->param('total_con'))
	    );
	    
	    $points{magic_points} = RPG::Schema::Character->roll_magic_points(1, $c->req->param('total_int'))
	        if $class->class_name eq 'Mage';
	    
	    $points{faith_points} = RPG::Schema::Character->roll_faith_points(1, $c->req->param('total_div'))
	        if $class->class_name eq 'Priest';
	                
	    $return = to_json(\%points);

	}
    
    $c->res->body($return);
}

sub complete : Local {
	my ($self, $c) = @_;
	
    $c->forward('RPG::V::TT',
        [{
            template => 'party/complete.html',
            params => {
            	party => $c->stash->{party},
            	town => $c->stash->{party}->location->town,
        	},
    	}]
	);	
}

1;