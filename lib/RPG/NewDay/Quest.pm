use strict;
use warnings;

package RPG::NewDay::Quest;

use Data::Dumper;

use Games::Dice::Advanced;
use List::Util qw(shuffle);

sub run {
	my $package = shift;
	my $config = shift;
	my $schema = shift;

	my $town_rs = $schema->resultset('Town')->search( );
		
	my @quest_types = $schema->resultset('Quest_Type')->search( 
		{
			hidden => 0,
		},
	);	
	my @first_level_quests = grep { $_->min_level == 1 } @quest_types;
	
	while (my $town = $town_rs->next) {	
		my $number_of_quests = int ($town->prosperity / $config->{prosperity_per_quest});
		
		my @quests = $schema->resultset('Quest')->search(
			{
				town_id => $town->id,
				party_id => undef,
			},
			{
				prefetch => 'type',
			},
		);
				
		next unless scalar @quests < $number_of_quests;
				
		my $number_of_first_level_quests = grep { $_->type->min_level == 1 } @quests;		
		
		for (scalar @quests .. $number_of_quests) {
			my $quest_type;
			
			if ($number_of_first_level_quests == 0) {
				shuffle @first_level_quests;
				$quest_type = $first_level_quests[0];
				$number_of_first_level_quests++;
			}
			else {
				@quest_types = shuffle @quest_types;
				$quest_type = $quest_types[0];
			}
			
			$schema->resultset('Quest')->create(
				{
					quest_type_id => $quest_type->id,
					town_id => $town->id,
				},
			);
		} 	
	}
	
}

1;