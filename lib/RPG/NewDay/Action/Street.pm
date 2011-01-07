package RPG::NewDay::Action::Street;

use Moose;

use Games::Dice::Advanced;
use List::Util qw(shuffle);

extends 'RPG::NewDay::Base';

sub depends { qw/RPG::NewDay::Action::Inn/ }

sub run {
    my $self = shift;
    my $context = $self->context;
	
	my @street_characters = $context->schema->resultset('Character')->search(
		{
			status => 'street',
		},
		{
			prefetch => 'party',
		},
	);
	
	my $day = $context->schema->resultset('Day')->find_today;
		
	foreach my $character (@street_characters) {
		my $town = $context->schema->resultset('Town')->find(
			{
				town_id => $character->status_context,
			},
		);
		
		if (Games::Dice::Advanced->roll('1d100') <= 5) {
			# Character killed
			$character->status('morgue');
			$character->hit_points(0);
			$character->update;
			
			my $message = $character->character_name . " was killed in a scuffle while living on the streets of " . $town->town_name;
			
			$context->schema->resultset('Party_Messages')->create(
				{
					message =>  $message . ". " . ucfirst $character->pronoun('posessive-subjective') . " body has been interred in the town morgue.",
					alert_party => 1,
					party_id => $character->party->id,
					day_id => $day->id,
				}
			);
			
			$character->add_to_history(
				{
					day_id => $day->id,
					event => $message,
				}
			);
		}
		
		elsif (Games::Dice::Advanced->roll('1d100') <= 15) {
			# Character robbed
			my @items = shuffle $character->items;
			
			my $stolen = Games::Dice::Advanced->roll('1d3');
			
			my $message = $character->character_name . " was robbed while living on the streets of " . $town->town_name . ". " .
				ucfirst $character->pronoun('subjective') . " lost the following items: ";
			
			my @items_lost;
			
			for (1 .. $stolen) {
				my $item = shift @items;
				
				next unless $item;

				push @items_lost, $item->display_name;
				
				$item->delete;
			}
			
			if (@items_lost) {			
				$message .= join ', ', @items_lost;
				
				$context->schema->resultset('Party_Messages')->create(
					{
						message =>  $message,
						alert_party => 1,
						party_id => $character->party->id,
						day_id => $day->id,
					}
				);
			}			
		}
	}
	
}

__PACKAGE__->meta->make_immutable;

1;
