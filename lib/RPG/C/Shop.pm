package RPG::C::Shop;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;
use Set::Object qw(set);

sub purchase : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;

	if ( $shop->status eq 'Closed' || $shop->status eq 'Opening' ) {
		$c->detach(
			'RPG::V::TT',
			[
				{
					template => 'shop/not_open.html',
					params   => {
						shop          => $shop,
						shops_in_town => \@shops_in_town,
						gold          => $party->gold,
					}
				}
			]
		);
	}

	my @characters = $party->characters;

	my @items = $shop->grouped_items_in_shop;

	# Get item_types 'made'
	my @item_types_made = $shop->item_types_made;

	# Get a sorted list of categories
	my @categories = $c->model('DBIC::Item_Category')->search( {}, { order_by => 'item_category', }, );

	my %items;

	# Put everything into a hash by category
	foreach my $item (@items) {
		push @{ $items{ $item->item_type->category->item_category }{item} }, $item;
	}

	foreach my $item_type (@item_types_made) {
		push @{ $items{ $item_type->category->item_category }{quantity} }, $item_type;
	}

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/purchase.html',
				params   => {
					shop          => $shop,
					characters    => \@characters,
					shops_in_town => \@shops_in_town,
					items         => \%items,
					gold          => $party->gold,
					town          => $party->location->town,
				}
			}
		]
	);
}

sub enchanted_tab : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;

	my @items = $shop->enchanted_items_in_shop;

	# Put everything into a hash by category
	my %items;
	foreach my $item (@items) {
		push @{ $items{ $item->item_type->category->item_category }{enchanted} }, $item;
	}

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/enchanted_items.html',
				params   => {
					shop  => $shop,
					items => \%items,
				}
			}
		]
	);
}

sub sell : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	my @shops_in_town = $party->location->town->shops;

	my ($shop) = grep { $c->req->param('shop_id') eq $_->id } @shops_in_town;

	my @characters = $party->characters;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/sell.html',
				params   => {
					shop          => $shop,
					characters    => \@characters,
					shops_in_town => \@shops_in_town,
					gold          => $party->gold,
					town          => $party->location->town,
					current_tab   => $c->session->{sell_active_tab} || '',
				}
			}
		]
	);
}

sub character_sell_tab : Local {
	my ( $self, $c ) = @_;

	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			garrison_id  => undef,
		}
	);

	croak "Invalid character" unless $character->party_id == $c->stash->{party}->id;

	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id') } );

	if ( $shop->town_id != $c->stash->{party}->location->town->id ) {
		croak "Invalid shop";
	}

	$c->session->{sell_active_tab} = $character->id;

	my @items = $c->model('DBIC::Items')->search(
		{ character_id => $c->req->param('character_id'), },
		{
			prefetch => [ { 'item_type' => 'category' }, 'item_variables', ],
			order_by => 'item_category',
		},
	);

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'shop/character_sell_tab.html',
				params   => {
					items     => \@items,
					shop      => $shop,
					character => $character,
				}
			}
		]
	);
}

sub buy_item : Local {
	my ( $self, $c ) = @_;

	my $shop = $c->model('DBIC::Shop')->find( $c->req->param('shop_id') );

	my $party = $c->stash->{party};

	my $town = $shop->in_town;

	if ( $town->id != 0 && $town->id != $party->location->town->id ) {
		$c->res->body( to_json( { error => "Attempting to buy an item in another town" } ) );

		# TODO: this does allow them to buy items from a different shop in the same town, which may or may not be OK
		return;
	}

	my $item;
	my $count = 0;
	my $cost = 0;

	if ( $c->req->param('item_type_id') ) {
		my $item_rs = $c->model('DBIC::Items')->search(
			{
				'item_type.item_type_id'           => $c->req->param('item_type_id'),
				shop_id                            => $shop->id,
				'item_enchantments.enchantment_id' => undef,
			},
			{
				prefetch => 'item_type',
				join     => 'item_enchantments',
			},
		);

		if ( $item_rs->count == 0 ) {
			$c->res->body(
				to_json( { error => "The shop no longer has any of those items left. Another party may have just bought the last one!" } ) );
			return;
		}

		$item  = $item_rs->first;
		$count = $item_rs->count - 1;		
		$cost = $item->item_type->modified_cost( $item->in_shop );
	}
	else {
		$item = $c->model('DBIC::Items')->find(
			{
				item_id => $c->req->param('item_id'),
				shop_id => $shop->id,
			},
			{
				prefetch => 'item_type',
			}
		);

		unless ($item) {
			$c->res->body( to_json( { error => "The shop no longer has this item. Another party may have bought it!" } ) );
			return;
		}
		
		$cost = $item->sell_price( $item->in_shop, 0 );
	}

	if ( $party->gold < $cost ) {
		$c->res->body( to_json( { error => "Your party doesn't have enough gold to buy this item" } ) );
		return;
	}
	
	# The town takes its cut
	$town->take_sales_tax($cost);
	$town->update;	

	my ($character) = grep { $_->id == $c->req->param('character_id') } $party->characters;

	$item->add_to_characters_inventory($character);

	$party->gold( $party->gold - $cost );
	$party->update;

	my $ret = to_json(
		{
			gold          => $party->gold,
			updated_stock => {
				item => $c->req->param('item_type_id') ? $c->req->param('item_type_id') : $c->req->param('item_id'),
				count => $count,
			},
		},
	);

	$c->res->body($ret);
}

# TODO: fair bit of duplication between this and buy_item
sub buy_quantity_item : Local {
	my ( $self, $c ) = @_;

	my $item_type = $c->model('DBIC::Item_Type')->find( { item_type_id => $c->req->param('item_type_id'), } );

	my $party = $c->stash->{party};

	# Make sure the shop they're in checks out
	my $shop = $c->model('DBIC::Shop')->find(
		{
			shop_id                   => $c->req->param('shop_id'),
			'items_made.item_type_id' => $c->req->param('item_type_id'),
		},
		{ join => 'items_made', },
	);

	unless ($shop) {
		$c->res->body( to_json( { error => "Attempting to buy an item type not in this shop" } ) );
		return;
	}

	# Make sure the shop they're in is in the town they're in
	if ( $shop->town_id != 0 && $shop->town_id != $party->location->town->id ) {
		$c->res->body( to_json( { error => "Attempting to buy an item in another town" } ) );

		# TODO: this does allow them to buy items from a different shop, which may or may not be OK
		return;
	}

	my $cost = $item_type->modified_cost($shop) * $c->req->param('quantity');

	if ( $party->gold < $cost ) {
		$c->res->body( to_json( { error => "Your party doesn't have enough gold to buy this item" } ) );
		return;
	}
	
	# The town takes its cut
	my $town = $shop->in_town;
	$town->take_sales_tax($cost);
	$town->update;	

	# Create the item
	my $item = $c->model('DBIC::Items')->create( { item_type_id => $c->req->param('item_type_id'), } );

	$item->variable( 'Quantity', $c->req->param('quantity') );
	$item->character_id( $c->req->param('character_id') );
	$item->update;

	$party->gold( $party->gold - $cost );
	$party->update;

	my $ret = to_json( { gold => $party->gold, } );

	$c->res->body($ret);
}

sub sell_item : Local {
	my ( $self, $c ) = @_;

	my $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), }, { prefetch => { 'item_type' => 'category' }, }, );
	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id'), } );

	if ( !$c->forward( 'sell_single_item', [ $item, $shop ] ) ) {
		return;
	}

	my $messages = $c->forward( '/quest/check_action', [ 'sell_item', $item ] );

	my $ret = to_json(
		{
			gold     => $c->stash->{party}->gold,
			messages => $messages,
		}
	);

	$c->res->body($ret);

}

sub sell_multi_item : Local {
	my ( $self, $c ) = @_;

	my $shop = $c->model('DBIC::Shop')->find( { shop_id => $c->req->param('shop_id'), } );
	my @item_ids = $c->req->param('item_id');

	my @items = $c->model('DBIC::Items')->search(
		{
			item_id => \@item_ids,
		},
		{ prefetch => { 'item_type' => 'category' }, },
	);

	my @messages;
	foreach my $item (@items) {
		if ( !$c->forward( 'sell_single_item', [ $item, $shop ] ) ) {
			return;
		}

		my $messages = $c->forward( '/quest/check_action', [ 'sell_item', $item ] );
		@messages = ( @messages, @$messages );
	}

	my $ret = to_json(
		{
			gold     => $c->stash->{party}->gold,
			messages => \@messages,
		}
	);

	$c->res->body($ret);
}

sub sell_single_item : Private {
	my ( $self, $c, $item, $shop ) = @_;

	# Make sure this item belongs to a character in the party
	my @characters = $c->stash->{party}->characters;
	if ( scalar( grep { $_->id eq $item->character_id } @characters ) == 0 ) {
		$c->log->warn( "Attempted to sell item "
				. $item->id
				. " by party "
				. $c->stash->{party}->id
				. ", but item does not belong to this party (item is owned by character: "
				. $item->character_id
				. ")" );
		return;
	}

	# Make sure the shop they're in is in the town they're in
	if ( $shop->town_id != $c->stash->{party}->location->town->id ) {
		$c->res->body( to_json( { error => "Attempting to sell an item in another town" } ) );

		# TODO: this does allow them to sell items from a different shop, which may or may not be OK
		return;
	}

	$c->stash->{party}->gold( $c->stash->{party}->gold + $item->sell_price($shop) );
	$c->stash->{party}->update;

	$item->character_id(undef);
	$item->equip_place_id(undef);

	if ( $item->variable('Quantity') || $item->upgraded ) {

		# Qunatity and upgraded items get deleted
		$item->delete;
	}

	else {

		# If it's not a quantity item, give it back to the shop, except for item categories without "auto_add_to_shop"
		if ( $item->item_type->category->auto_add_to_shop ) {
			if ($item->has_variable('Durability')) {
				# Reset the item's durability
				$item->variable('Durability', $item->variable_max('Durability'));
			}			
			
			$item->shop_id( $shop->id );
			$item->update;
		}
		else {
			$item->delete;
		}
	}

	return 1;
}

1;
