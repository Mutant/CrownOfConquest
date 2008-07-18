package RPG::C::Item;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub tooltip : Local {
	my ($self, $c) = @_;
	
	my $item_type_id;
	my $item;
	
	if ($c->req->param('item_id')) {
		$item = $c->model('DBIC::Items')->find(
			{
				item_id => $c->req->param('item_id'),
			},
		);
		
		$item_type_id = $item->item_type_id;
	}
	else {
		$item_type_id = $c->req->param('item_type_id');
	}
	
	my $item_type = $c->model('DBIC::Item_Type')->find(
		{
			item_type_id => $item_type_id,
		},
		{
			prefetch => [
				#{'category' => ['item_variable_names','item_attribute_names']},
				{'item_attributes' => 'item_attribute_name'},
			],
		},
	);
	
	$c->forward('RPG::V::TT',
        [{
            template => 'item/tooltip.html',
			params => {
				item => $item,
				item_type => $item_type,
			},
        }]
    );
}

1;