package RPG::C::Quest;

use strict;
use warnings;
use base 'Catalyst::Controller';

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
	
	my @quests = $c->stash->{party}->quests;

	$c->forward('RPG::V::TT',
        [{
            template => 'quest/list.html',
			params => {
				quests => \@quests,
			},
        }]
    );
}

1;