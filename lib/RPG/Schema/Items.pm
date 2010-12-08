package RPG::Schema::Items;
use base 'DBIx::Class';
use strict;
use warnings;

use Moose;

use Carp;
use Data::Dumper;
use Math::Round qw(round);
use Games::Dice::Advanced;

use RPG::Template;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Items');

__PACKAGE__->resultset_class('RPG::ResultSet::Items');

__PACKAGE__->add_columns(
    'item_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 1,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'item_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'item_type_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 1,
        'name'              => 'item_type_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'magic_modifier' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'magic_modifier',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'name' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'name',
        'is_nullable'       => 1,
        'size'              => '255'
    },
    'character_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'character_id',
        'accessor'          => '_character_id',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'shop_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'shop_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'equip_place_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'equip_place_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'treasure_chest_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'treasure_chest_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'garrison_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'garrison_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },    
    'land_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'land_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },      

);
__PACKAGE__->set_primary_key('item_id');

__PACKAGE__->belongs_to( 'item_type', 'RPG::Schema::Item_Type', { 'foreign.item_type_id' => 'self.item_type_id' } );

__PACKAGE__->belongs_to( 'in_shop', 'RPG::Schema::Shop', { 'foreign.shop_id' => 'self.shop_id' } );

__PACKAGE__->belongs_to( 'belongs_to_character', 'RPG::Schema::Character', { 'foreign.character_id' => 'self.character_id' } );

__PACKAGE__->belongs_to( 'equipped_in', 'RPG::Schema::Equip_Places', { 'foreign.equip_place_id' => 'self.equip_place_id' } );

__PACKAGE__->has_many( 'item_variables', 'RPG::Schema::Item_Variable', { 'foreign.item_id' => 'self.item_id' } );

__PACKAGE__->has_many( 'item_enchantments', 'RPG::Schema::Item_Enchantments', 'item_id' );

__PACKAGE__->many_to_many( 'enchantments' => 'item_enchantments', 'enchantment' );

with 'RPG::Schema::Item::Variables';

sub variables {
	my $self = shift;
	
	return $self->item_variables;	
}

sub attribute {
    my $self      = shift;
    my $attribute = shift;

    return $self->item_type->attribute($attribute);
}


sub display_name {
    my $self = shift;

	my $name = $self->item_type->item_type;

    if ( my $quantity = $self->variable('Quantity') ) {
        $name .= ' (x' . $quantity . ')';
    }

    return $name;
}

sub weight {
    my $self = shift;
	
	my $base_weight = $self->item_type->weight;

	my $featherweight = $self->find_related(
		'item_enchantments',
		{
			'enchantment.enchantment_name' => 'featherweight',
		},
		{
			join => 'enchantment',
		}
	);
	
	if ($featherweight) {
		$base_weight -= round($base_weight * $featherweight->variable('Featherweight') / 100);	
	}

    if ( my $quantity = $self->variable('Quantity') ) {
		return $quantity  * $base_weight;
    }
    else {
	    return $base_weight;
    }	
}

# Override insert to populate item_variable data
sub insert {
    my ( $self, @args ) = @_;
    
    $self->next::method(@args);    

    my @item_variable_params = $self->item_type->search_related( 'item_variable_params', {}, { prefetch => 'item_variable_name', }, );

    foreach my $item_variable_param (@item_variable_params) {
        next unless $item_variable_param->item_variable_name->create_on_insert;

        my $range      = $item_variable_param->max_value - $item_variable_param->min_value + 1;
        my $init_value = Games::Dice::Advanced->roll("1d$range") + $item_variable_param->min_value - 1;
        $self->add_to_item_variables(
            {
                item_variable_name_id => $item_variable_param->item_variable_name->id,
                item_variable_value   => $init_value,
                max_value             => $item_variable_param->keep_max ? $init_value : undef,
            }
        );
    }
    
    return $self;
}

sub new {
	my ( $class, $attr ) = @_;

    my $self = $class->next::method($attr);
    
    $self->_encumbrace_trigger($self->_character_id) if $self->_character_id;

    return $self;	
}

sub delete {
    my ( $self, @args ) = @_;

	$self->_check_for_quest_item_removal();
	
	$self->_encumbrace_trigger(undef);
	
    my $ret = $self->next::method(@args);

    return $ret;
}

sub update {
	my ( $self, $attr ) = @_;

	if (exists $attr->{character_id}) {
		$self->_encumbrace_trigger($attr->{character_id});	
	}
	
    my $ret = $self->next::method($attr);

    return $ret;	
}


sub character_id {
	my $self = shift;

	$self->_encumbrace_trigger(@_) if @_;
	
	return $self->_character_id;	
}

sub _encumbrace_trigger {
	my $self = shift;
	my $new_char_id = shift;

	my $current_char_id = $self->_character_id;
 
	if (defined $current_char_id) {
		my $character = $self->belongs_to_character;
		$character->calculate_encumbrance(-$self->weight) if $character;
	}

	if (defined $new_char_id) {
		my $character = $self->result_source->schema->resultset('Character')->find(
			{
				character_id => $new_char_id,
			}
		);
		$character->calculate_encumbrance($self->weight) if $character;
	}	

	
	$self->_character_id($new_char_id);
	
}

sub sell_price {
    my $self = shift;
    my $shop = shift;
    my $use_modifier = shift // 1;
    my $adjust_for_damage = shift // 1;

    my $modifier = $use_modifier ? RPG::Schema->config->{shop_sell_modifier} : 0;

	my $price = $self->item_type->modified_cost($shop);

    # Adjust for upgrades
    my @upgrade_variables = $self->item_type->category->variables_in_property_category('Upgrade');
    foreach my $upgrade_variable (@upgrade_variables) {
        $price += ( $self->variable($upgrade_variable) || 0 ) * 20;
    }
    
    # Adjust for enchantments
    my @enchantments = $self->item_enchantments;
    foreach my $enchantment (@enchantments) {
    	$price += ($enchantment->sell_price_adjustment || 0);	
    }

    $price *= $self->variable('Quantity') if $self->variable('Quantity');
    
    # Adjust for repair cost
    if ($adjust_for_damage and my $repair_cost = $self->repair_cost) {
    	$price -= $repair_cost;	
    }

    $price = int( $price / ( 100 / ( 100 + $modifier ) ) );

    $price = 1 if $price <= 0;

    return $price;
}

=head2 equip_item($equipment_slot_name, $replace_existing_equipment)

Equip an item  belonging to a particular character in a given equipment slot. Checks that the item can be equipped in that slot,
throwing an exception if it can't be.

The $replace_existing_equipment is a boolean (defaults to true) that specifies whether any existing equipment should be removed
to complete the equip (including considerations for things such as two-handed weapons).

Returns a list of equip slot names that have been changed (or an empty list if nothing has changed). Note, if the item is already
equiped elsewhere, the slot it's being moved to will be in the return list.

=cut

sub equip_item {
    my $self                       = shift;
    my $equipment_slot_name        = shift;
    my $replace_existing_equipment = shift;
    $replace_existing_equipment = 1 unless defined $replace_existing_equipment;

    my ($equip_place) = $self->result_source->schema->resultset('Equip_Places')->search(
        {
            equip_place_name                          => $equipment_slot_name,
            'equip_place_categories.item_category_id' => $self->item_type->item_category_id,
        },
        { join => 'equip_place_categories', },
    );

    my @slots_changed;

    # Make sure this category of item can be equipped here
    unless ($equip_place) {
    	# TODO: replace with RPG::Exception
        croak "Can't equip an item of that type there\n";
    }

    # If the item is alredy equipped there, return straight away
    if ( $self->equip_place_id && $self->equip_place_id == $equip_place->id ) {
        return;
    }

    # See if an item is already equipped there
    my ($equipped_item) = $self->result_source->schema->resultset('Items')->search(
        {
            character_id   => $self->character_id,
            equip_place_id => $equip_place->id,
        }
    );

    if ($equipped_item) {
        if ($replace_existing_equipment) {
            $equipped_item->equip_place_id(undef);
            $equipped_item->update;
        }
        else {

            # We're not replacing existing items, so nothing more to do here
            return;
        }
    }

    # Check to see if we're going to affect the opposite hand's equipped item
    my $other_hand = $equip_place->opposite_hand;

    if ($other_hand) {
        my ($item_in_opposite_hand) = $self->result_source->schema->resultset('Items')->search(
            {
                character_id   => $self->character_id,
                equip_place_id => $other_hand->id,
            },
            { prefetch => { 'item_type' => { 'item_attributes' => 'item_attribute_name' } }, },
        );

        # If this item and the item in opposite hand are both weapons, we have to unequip old weapon
        #  unless $replace_existing_equipment is false, in which case we return
        # This is temporary while two weapons can't be equipped
        if (   $item_in_opposite_hand
            && $item_in_opposite_hand->item_type->category->super_category->super_category_name eq 'Weapon'
            && $self->item_type->category->super_category->super_category_name eq 'Weapon' )
        {
            if ($replace_existing_equipment) {
                $item_in_opposite_hand->equip_place_id(undef);
                $item_in_opposite_hand->update;
                push @slots_changed, $other_hand->equip_place_name;
            }
            else {
                return;
            }
        }
        else {

            # Check if we're equipping a two-handed weapon, or there's one already equipped
            my $attribute = $self->attribute('Two-Handed');
            my $opposite_hand_attribute = $item_in_opposite_hand ? $item_in_opposite_hand->attribute('Two-Handed') : undef;
            if ( ( $attribute && $attribute->value ) || ( $opposite_hand_attribute && $opposite_hand_attribute->value ) ) {

                if ( $item_in_opposite_hand && $item_in_opposite_hand->id != $self->id ) {
                    if ($replace_existing_equipment) {
                        $item_in_opposite_hand->equip_place_id(undef);
                        $item_in_opposite_hand->update;
                        push @slots_changed, $other_hand->equip_place_name;
                    }
                    else {

                        # Equipping this item would unequip another, but $replace_existing_equipment is false, so return
                        return;
                    }
                }
            }
        }
    }

    # Check if this item is already equipped. If it is, record the fact that it's current slot has changed.
    if ( $self->equip_place_id ) {
        push @slots_changed, $self->equipped_in->equip_place_name;
    }

    $self->equip_place_id( $equip_place->id );
    $self->update;
    push @slots_changed, $equipment_slot_name;

    return @slots_changed;
}

# Add item to a characters equipment list, including auto-equipping if necessary
sub add_to_characters_inventory {
    my $self      = shift;
    my $character = shift;

    croak "Must pass a character record to add_to_characters_inventory()"
        unless $character->isa('RPG::Schema::Character');

    $self->character_id( $character->id );
    $self->shop_id(undef);
    $self->treasure_chest_id(undef);
    $self->garrison_id(undef);
	$self->land_id(undef);

    my $category = $self->item_type->category;

    my %equipped_items = %{ $character->equipped_items() };

    # Try equipping the item in each empty equip place (without removing any existing items)
    LOOP: foreach my $equip_place (keys %equipped_items) {
        if ( !$equipped_items{$equip_place} ) {
            eval {
                if ( $self->equip_item( $equip_place, 0 ) )
                {

                    # Equip was successful, so don't try to equip again
                    no warnings;
                    last LOOP;
                }
            };
            if ($@) {
                unless ( $@ =~ "Can't equip an item of that type there" ) {
                    croak $@;
                }
            }
        }
    }

    # May do nothing, since equip_item does an update, but if nothing was auto equipped, we need to do this
    $self->update;

    return;
}

# Cost to upgrade a particular variable on this item
# TODO: not sure this belongs here? some items can't be upgraded...
sub upgrade_cost {
    my $self     = shift;
    my $variable = shift;

    my $current_value = $self->variable($variable) || 0;

    my $cost_factor = int 2**round( $current_value / 3 );

    return $cost_factor * RPG::Schema->config->{base_item_upgrade_cost};

}

sub upgraded {
    my $self = shift;

    my @upgrade_vars = $self->item_type->category->variables_in_property_category('Upgrade');
    foreach my $upgrade_variable (@upgrade_vars) {
        return 1 if $self->variable($upgrade_variable);
    }

    return 0;
}

sub repair_cost {
    my $self = shift;
    my $town = shift;

    my $variable_rec = $self->variable_row('Durability');

    return 0 if !$variable_rec || !defined $variable_rec->max_value || $variable_rec->max_value == $variable_rec->item_variable_value;

    my $full_repair_cost = $self->sell_price(undef, 0, 0) * 0.25;

    my $percent_damaged = ( $variable_rec->max_value - $variable_rec->item_variable_value ) / $variable_rec->max_value;
    
    my $cost = $full_repair_cost * $percent_damaged;
    
    $cost -= $cost * ($town->blacksmith_skill / 100) if $town;
      
    my $character = $self->belongs_to_character;
    my $party;
    $party = $character->party if $character;
        
    if ($party && $town && $town->discount_type && $town->discount_type eq 'blacksmith' && $party->prestige_for_town($town) >= $town->discount_threshold ) {
        $cost = round ($cost * ( 100 - $town->discount_value) / 100 );   
    }
        
    $cost = 1 if $cost < 1;
        
    return round($cost);
}

# Returns the currently usable actions for this item. Each enchantment on the item (if any) is checked to see
#  if it can be used,  and the criteria for that action must be satisfied 
#  (e.g. the item is equipped if the action requires that)
sub usable_actions {
	my $self = shift;
	my $combat = shift;
	
	return @{$self->{_actions}{$combat}} if $self->{_actions}{$combat}; 
	
	my @enchantments = $self->item_enchantments;
	return unless @enchantments;
	
	my @actions;
	foreach my $enchantment (@enchantments) {
		next unless $enchantment->is_usable($combat);
		if ($enchantment->must_be_equipped) {
			push @actions, $enchantment if $self->equipped;
		}
		else {
			push @actions, $enchantment;
		}
	}
	
	$self->{_actions}{$combat} = \@actions;
	
	return @actions;
}

sub equipped {
	my $self = shift;
	
	return $self->equip_place_id ? 1 : 0;	
}

sub slot_equipped_in {
	my $self = shift;
	
	return unless $self->equipped;
	
	return $self->equipped_in->equip_place_name;
	
}

sub enchantments_count {
	my $self = shift;
	
	return $self->search_related('item_enchantments')->count();	
}

# Check if the item is for a quest before it's deleted.
#  If so, the quest needs to be terminated, and a message left for the party.
sub _check_for_quest_item_removal {
	my $self = shift;		
	
	return unless $self->item_type->item_type eq 'Artifact';
	
	my $quest = $self->result_source->schema->resultset('Quest')->find(
		{
			status => 'In Progress',
			'type.quest_type' => 'find_dungeon_item',
			'quest_param_name.quest_param_name' => 'Item',
			'quest_params.start_value' => $self->id,
		},
		{
			join => ['type', {'quest_params' => 'quest_param_name'}],
		}
	);
	
	if ($quest) {
		# Terminate this quest, and add a party message
		my $message = RPG::Template->process(
			RPG::Schema->config,
			'quest/misc/find_dungeon_item_lost_item.html',
			{
				quest => $quest,
			}
		);		
		
		$quest->terminate($message);
		$quest->update;
	}

}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);


1;
