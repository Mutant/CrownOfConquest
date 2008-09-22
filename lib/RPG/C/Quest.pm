package RPG::C::Quest;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub offer : Local {
	my ($self, $c) = @_;
	
	my $quest = $c->model('DBIC::Quest')->find(
		{
			quest_id => $c->req->param('quest_id'),
			town_id => $c->stash->{party_location}->town->id,
			party_id => undef,
		},
	);
	
	$c->forward('RPG::V::TT',
        [{
            template => 'quest/offer.html',
			params => {
				town => $c->stash->{party_location}->town,
				quest => $quest,
			},
        }]
    );
}

sub accept : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party_location}->town;
	
	my $quest = $c->model('DBIC::Quest')->find(
		{
			quest_id => $c->req->param('quest_id'),
			town_id => $town->id,
			party_id => undef,
		},
	);
	
	$quest->party_id($c->stash->{party}->id);
	$quest->update;
	
	# If this town has no quests left, create a new quest of the same type
	if ($c->model('DBIC::Quest')->count({ town_id => $town->id, party_id => undef, }) == 0) {
		$c->model('DBIC::Quest')->create(
			{
				town_id => $town->id,
				quest_type_id => $quest->quest_type_id,
			}
		);	
	} 
}

sub list : Local {
	my ($self, $c) = @_;
	
	my @quests = $c->model('DBIC::Quest')->search(
		{
			party_id => $c->stash->{party}->id,
			complete => 0,
		},
		{
			prefetch => [
				'quest_params',
				{'type' => 'quest_param_names'},
			],
		}
	);

	$c->forward('RPG::V::TT',
        [{
            template => 'quest/list.html',
			params => {
				quests => \@quests,
			},
        }]
    );
}

# Check the party's quests to see if any progress has been made for the particular action just taken
sub check_action : Private {
	my ($self, $c, $action) = @_;
	
	my @messages;
	
	foreach my $quest ($c->stash->{party}->quests) {
		if ($quest->check_action($c->stash->{party}, $action)) {
			push @messages, $c->forward('RPG::V::TT',
		        [{
		            template => 'quest/action_message.html',
					params => {
						quest => $quest,
						action => $action,
					},
					return_output => 1,
		        }]
		    );
		}	
	}
		
	return \@messages;
}

1;