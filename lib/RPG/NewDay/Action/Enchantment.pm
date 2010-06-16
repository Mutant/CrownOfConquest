package RPG::NewDay::Action::Enchantment;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;

sub depends { qw/RPG::NewDay::Action::CreateDay/ };

sub run {
    my $self = shift;

    my $c = $self->context;
    
	my @items = $c->schema->resultset('Items')->search(
		{
			'item_enchantments.enchantment_id' => {'!=', undef},
		},
		{
			prefetch => 'item_enchantments',
		}			
	);
	
	foreach my $item (@items) {
		foreach my $enchantment ($item->item_enchantments) {
			if ($enchantment->can('new_day')) {
				$enchantment->new_day($c);	
			}
		}	
	}    
}

1;