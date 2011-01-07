package RPG::NewDay::Action::Inn;

use Moose;

extends 'RPG::NewDay::Base';

sub run {
    my $self = shift;
    my $context = $self->context;

	my @towns = $context->schema->resultset('Town')->search( {}, { prefetch => 'location', } );
	
	foreach my $town (@towns) {
		my @inn_characters = $context->schema->resultset('Character')->search(
			{
				status => 'inn',
				status_context => $town->id,
			},
		);
		
		foreach my $character (@inn_characters) {
			my $cost = $town->inn_cost($character);
			
			my $party = $character->party;
			
			if ($character->party->gold < $cost) {
				# Character can't pay - thrown out of the inn
				$character->status('street');
				$character->update;
				
				$context->schema->resultset('Party_Messages')->create(
					{
						message => $character->character_name . " couldn't afford " . $character->pronoun('posessive-subjective') 
							. " board at the inn of " . $town->town_name . ", so was thrown out by the guards!",
						alert_party => 1,
						party_id => $party->id,
						day_id => $context->schema->resultset('Day')->find_today->id,
					}
				);				
			}
			else {
				$party->decrease_gold($cost);
				$party->update;
				
				$party->add_to_day_logs(
					{
						day_id => $context->schema->resultset('Day')->find_today->id,
						log    => $character->character_name . " paid $cost gold for board to the inn of " . $town->town_name,
					}
				);				
			}
		} 	
	}   
}

__PACKAGE__->meta->make_immutable;

1;
