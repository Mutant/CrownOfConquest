package RPG::Schema::Items;
use base 'DBIx::Class';
use strict;
use warnings;

use Moose;

use Carp;
use Data::Dumper;
use Math::Round qw(round);
use Games::Dice::Advanced;
use Try::Tiny;

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
        'accessor'          => '_equip_place_id',
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

__PACKAGE__->has_many( 'grid_sectors', 'RPG::Schema::Item_Grid', 'item_id', { cascade_delete => 0 } );

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
    my $show_enchanted_star = shift // 0;

	my $name = $self->item_type->item_type;

    if ( my $quantity = $self->variable('Quantity') ) {
        $name .= ' (x' . $quantity . ')';
    }
    
    if ($show_enchanted_star) {
        my $enchanted = $self->enchantments_count > 0 ? 1 : 0;
    
        $name .= $enchanted ? '(*)' : '';
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
    
    my $item_type = $self->item_type;
    
    confess "No item_type found for item id " . $self->id unless $item_type;

    my @item_variable_params = $item_type->search_related( 'item_variable_params', {}, { prefetch => 'item_variable_name', }, );

    foreach my $item_variable_param (@item_variable_params) {
        next if ! $item_variable_param->item_variable_name->create_on_insert || $item_variable_param->special;

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
    
    $self->_apply_role;
    
    if ($self->can('set_special_vars')) {
        $self->set_special_vars(@item_variable_params);   
    }
    
    return $self;
}

sub inflate_result {
    my $pkg = shift;

    my $self = $pkg->next::method(@_);

    $self->_apply_role;

    return $self;
}

sub new {
	my ( $class, $attr ) = @_;

    my $self = $class->next::method($attr);
    
    $self->_item_ownership_change_triggers($self->_character_id) if $self->_character_id;
    
    $self->equip_place_id($self->_equip_place_id, {force_triggers => 1}) if $self->_equip_place_id;
    
    return $self;	
}

sub delete {
    my ( $self, @args ) = @_;

	$self->_check_for_quest_item_removal();
	
	$self->_item_ownership_change_triggers(undef, $self->_character_id);
	$self->equip_place_id(undef);
	
    my $ret = $self->next::method(@args);

    return $ret;
}

sub update {
	my ( $self, $attr ) = @_;

	if (exists $attr->{character_id}) {
		$self->_item_ownership_change_triggers($attr->{character_id}, $self->_character_id);	
	}
	
    my $ret = $self->next::method($attr);

    return $ret;	
}


sub character_id {
	my $self = shift;

	if (@_) {
		my $new_char_id = shift;
	
		no warnings 'uninitialized';
	
		# Equip place always gets cleared when character changes
		#  This makes sure the ownership triggers are run correctly
		$self->equip_place_id(undef) if $new_char_id != $self->character_id;

		my $current_char_id = $self->_character_id;
	
		$self->_item_ownership_change_triggers($new_char_id, $current_char_id);
	
		$self->_character_id($new_char_id);
	}
		
	return $self->_character_id;	
}

sub _item_ownership_change_triggers {
	my $self = shift;
	my $new_char_id = shift;
	my $current_char_id = shift;
	
	return if defined $new_char_id && defined $current_char_id && $new_char_id == $current_char_id;
	
	my ($current_char, $new_char);
	
	if (defined $current_char_id) {
		$current_char = $self->belongs_to_character;
	}
	if (defined $new_char_id) {
		$new_char = $self->result_source->schema->resultset('Character')->find(
			{
				character_id => $new_char_id,
			}
		);	    
	}
	
	$self->_encumbrace_trigger($new_char, $current_char);
	$self->_usable_actions_ownership_trigger($new_char, $current_char);
	
	$new_char->update if $new_char;
	$current_char->update if $current_char;
    
}

sub _encumbrace_trigger {
	my $self = shift;
	my $new_char = shift;
	my $current_char = shift;
 
    $current_char->calculate_encumbrance(-$self->weight) if $current_char;
	$new_char->calculate_encumbrance($self->weight) if $new_char;
}

sub equip_place_id {
	my $self = shift;

	if (@_) {
		my $new_equip_place_id = shift;
		my $trigger_params = shift || {}; 
		
		no warnings 'uninitialized';

		if ($trigger_params->{force_triggers} || $new_equip_place_id != $self->_equip_place_id) {
			if ($self->_character_id) {
				my $character = $self->result_source->schema->resultset('Character')->find(
					{
						character_id => $self->_character_id,
					}
				);
				
				if ($character) {				
    				my @stats_with_bonuses = $self->_stat_bonus_trigger($new_equip_place_id, $character);
    				$self->_movement_factor_bonus_trigger($new_equip_place_id, $character);
    				$self->_factors_trigger($new_equip_place_id, $character, @stats_with_bonuses)
    				    unless $trigger_params->{no_factors_trigger};
    				    
    				$self->_resistance_bonus_trigger($new_equip_place_id, $character);
    				$self->_usable_actions_trigger($new_equip_place_id, $character);
    				
    				$character->update;
				}
			}
		}
		
		$self->_equip_place_id($new_equip_place_id);
	}
		
	return $self->_equip_place_id;	
}

sub _stat_bonus_trigger {
	my $self = shift;
	my $new_equip_place_id = shift;
	my $character = shift;
	
	my @stat_bonuses = $self->search_related(
		'item_enchantments',
		{
			'enchantment.enchantment_name' => 'stat_bonus',
		},
		{
			join => 'enchantment',
		}
	);
		
	my @stats_with_bonuses;
		
	foreach my $stat_bonus (@stat_bonuses) {
		my $stat  = $stat_bonus->variable('Stat Bonus');
		push @stats_with_bonuses, $stat;
		my $bonus = $stat_bonus->variable('Bonus');

		my $method = "adjust_" . $stat . "_bonus";
		
		$bonus = -$bonus unless defined $new_equip_place_id; 
		
		$character->$method($bonus);		
	}
	
	return @stats_with_bonuses;
}

sub _movement_factor_bonus_trigger {
	my $self = shift;
	my $new_equip_place_id = shift;
	my $character = shift;	
	
	my @bonuses = $self->search_related(
		'item_enchantments',
		{
			'enchantment.enchantment_name' => 'movement_bonus',
		},
		{
			join => 'enchantment',
		}
	);
	
	foreach my $bonus (@bonuses) {
		my $bonus = $bonus->variable('Movement Bonus');
		$bonus = -$bonus unless defined $new_equip_place_id;
		
		$character->adjust_movement_factor_bonus($bonus);
	}
}

sub _factors_trigger {
	my $self = shift;
	my $new_equip_place_id = shift;
	my $character = shift;
	my @stats_with_bonuses = @_;
		
	return unless $character;
		
	my $key = defined $new_equip_place_id ? 'add' : 'remove';
	
	if (my $af_attr = $self->attribute('Attack Factor')) {
	   $character->calculate_attack_factor({$key => [$self]});
	}
	# If we're not equipping something with AF, but the item changes str or agl, 
	#  we need to calculate attack factor
	elsif (grep { $_ ~~ [qw/strength agility/] } @stats_with_bonuses) {
	   $character->calculate_attack_factor;
	}
	
	if (my $df_attr = $self->attribute('Defence Factor')) {
	   $character->calculate_defence_factor({$key => [$self]});
	}	
	# Ditto DF
	elsif (grep { $_ eq 'agility' } @stats_with_bonuses) {
	   $character->calculate_defence_factor;
	}
}

sub _resistance_bonus_trigger {
	my $self = shift;
	my $new_equip_place_id = shift;
	my $character = shift;
	
	return unless $character;
		
	my @enchantments = $self->search_related(
		'item_enchantments',
		{
			'enchantment.enchantment_name' => 'resistances',
		},
		{
			join => 'enchantment',
		}
	);
	
	foreach my $enchantment (@enchantments) {
		my $bonus = $enchantment->variable('Resistance Bonus');
		my $type = $enchantment->variable('Resistance Type');
		$bonus = -$bonus unless defined $new_equip_place_id;
		
		my $method = "adjust_resist_${type}_bonus";
		
		$character->$method($bonus);
	}    
}

sub _usable_actions_trigger {
    my $self = shift;
	my $new_equip_place_id = shift;
	my $character = shift;    
        
    my @columns = qw(has_usable_actions_non_combat has_usable_actions_combat);
    
    undef $self->{_actions};
    
    for my $combat (0,1) {        
        my @actions = $self->usable_actions(combat => $combat, is_equipped => 1);
        next if ! @actions;
        
        my $col = $columns[$combat];
        
        if (defined $new_equip_place_id) {
            $character->$col(1);
        }
        else {
            my @existing_actions = grep { $_->item_id != $self->id } $character->get_item_actions($combat);
            $character->$col(@existing_actions ? 1 : 0);
        }
    }        
}

sub _usable_actions_ownership_trigger {
    my $self = shift;
    my $new_char = shift;
    my $current_char = shift;
    
    my @columns = qw(has_usable_actions_non_combat has_usable_actions_combat);
    
    for my $combat (0,1) { 
        my @new_char_actions = $self->usable_actions(combat => $combat, character => $new_char);
        my @current_char_actions = $self->usable_actions(combat => $combat, character => $current_char);
        
        my $col = $columns[$combat];
        
        $new_char->$col(1) if @new_char_actions && $new_char;
        
        if ($current_char && @current_char_actions && ! grep { $_->item_id != $self->id } $current_char->get_item_actions($combat)) {
            $current_char->$col(0);
        }   
    }   
}

sub sell_price {
    my $self = shift;
    my $shop = shift;
    my $use_modifier = shift // 1;
    my $adjust_for_damage = shift // 1;
    my $single_item = shift // 0;

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

    $price *= $self->variable('Quantity') if $self->variable('Quantity') && ! $single_item;
    
    # Adjust for repair cost
    if ($adjust_for_damage and my $repair_cost = $self->repair_cost) {
    	$price -= $repair_cost;	
    }

    $price = int( $price / ( 100 / ( 100 + $modifier ) ) );

    $price = 1 if $price <= 0;
    
    # Can't be less than 1 gold per item (for quantity items)
    if ($self->variable('Quantity') && ! $single_item && $price < $self->variable('Quantity')) {
       $price = $self->variable('Quantity');
    }

    return $price;
}

# Sell price for an individual item
#  Returns undef is not a quantity item, or there is only 1 of this item
sub individual_sell_price {
    my $self = shift;
    my $shop = shift;
    
    return if ! $self->variable('Quantity') || $self->variable('Quantity') == 1;
    
    return $self->sell_price($shop, undef, undef, 1);
}

sub is_quantity {
    my $self = shift;
    
    return $self->variable('Quantity') ? 1 : 0;
}

=head2 equip_item($equipment_slot_name, replace_existing_equipment => 0)

Equip an item  belonging to a particular character in a given equipment slot. Checks that the item can be equipped in that slot,
throwing an exception if it can't be.

The replace_existing_equipment is a boolean (defaults to true) that specifies whether any existing equipment should be removed
to complete the equip (including considerations for things such as two-handed weapons).

Returns any extra items that were also unequipped as the result of the item being equipped

=cut

sub equip_item {
    my $self                       = shift;
    my $equipment_slot_name        = shift;
    my %params = @_;
        
    my $replace_existing_equipment = $params{replace_existing_equipment} // 1;

    my ($equip_place) = $self->result_source->schema->resultset('Equip_Places')->search(
        {
            equip_place_name                          => $equipment_slot_name,
            'equip_place_categories.item_category_id' => $self->item_type->item_category_id,
        },
        { 
            join => 'equip_place_categories', 
        },
    );

    # Make sure this category of item can be equipped here
    unless ($equip_place) {
    	# TODO: replace with RPG::Exception
        croak "Can't equip an item of that type there\n";
    }

    # If the item is already equipped there, return straight away
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
    
    my $character = $self->belongs_to_character;    
    $character->remove_item_from_grid($self);

    if ($equipped_item) {
        if ($replace_existing_equipment) {
            $equipped_item->equip_place_id(undef);
            $equipped_item->update;
            
            $character->add_item_to_grid($equipped_item, 
                { 
                    x => $params{'existing_item_x'}, 
                    y => $params{'existing_item_y'} 
                } 
            );            
        }
        else {
            # We're not replacing existing items, so nothing more to do here
            return;
        }
    }

    my @extra_items;

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
        # Note, we bypass the 'factors trigger' when unequipping these items. This is an optimisation,
        #  since we don't want to trigger calculation of attack/defence factor until we equip the actual
        #  item.
        if (   $item_in_opposite_hand
            && $item_in_opposite_hand->item_type->category->super_category->super_category_name eq 'Weapon'
            && $self->item_type->category->super_category->super_category_name eq 'Weapon' )
        {
            if ($replace_existing_equipment) {
                # Order here is important... we want to unequip, then add to grid
                #  before updating to DB. Adding to grid may throw an exception
                $item_in_opposite_hand->equip_place_id(undef, {no_factor_trigger => 1});
                $character->add_item_to_grid($item_in_opposite_hand);
                $item_in_opposite_hand->update;                
                push @extra_items, $item_in_opposite_hand;
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
                        $item_in_opposite_hand->equip_place_id(undef, {no_factor_trigger => 1});
                        
                        try {
                            $character->add_item_to_grid($item_in_opposite_hand);
                        }
                        catch {
                            # Not enough room in inventory grid to add off hand item.
                            #  Put exisiting item back in slot and rethrow
                            if ($_ =~ /^Couldn't find room for item/ && $equipped_item) {                                
                                $character->remove_item_from_grid($equipped_item);                                
                                $equipped_item->equip_place_id( $equip_place->id );
                                $equipped_item->update;
                            }
                            
                            die $_;
                        };
                            
                                                    
                        $item_in_opposite_hand->update;
                        push @extra_items, $item_in_opposite_hand;
                    }
                    else {

                        # Equipping this item would unequip another, but $replace_existing_equipment is false, so return
                        return;
                    }
                }
            }
        }
    }
    
    $self->equip_place_id( $equip_place->id );
    $self->update;

    return @extra_items;
}

# Add item to a characters equipment list, including auto-equipping if necessary
sub add_to_characters_inventory {
    my $self      = shift;
    my $character = shift;
    my $grid_loc  = shift;
    my $auto_eqip = shift // 1;

    croak "Must pass a character record to add_to_characters_inventory() - got: $character"
        unless $character->isa('RPG::Schema::Character');

    $self->character_id( $character->id );
    $self->shop_id(undef);
    $self->treasure_chest_id(undef);
    $self->garrison_id(undef);
	$self->land_id(undef);
        
    if ($self->variable('Quantity')) {
        # Stack quantity items
        my $item = $character->search_related(
            'items',
            {
                'me.item_type_id' => $self->item_type_id,
            }
        )->first;
        
        if ($item) {
            # They have an existing item, so stack it
            $item->variable_row('Quantity', $item->variable('Quantity') + $self->variable('Quantity'));
            
            # Don't delete this item, just don't add it to inventory
            $self->character_id(undef);
            $self->update;
            return $item;             
        }   
    }

    my $category = $self->item_type->category;
    
    if ($auto_eqip && $category->equip_place_categories->count > 0 ) {
    
        my %equipped_items = %{ $character->equipped_items() };
    
        # Try equipping the item in each empty equip place (without removing any existing items)
        LOOP: foreach my $equip_place (keys %equipped_items) {
            if ( !$equipped_items{$equip_place} ) {
                try {
                    if ( $self->equip_item( $equip_place, replace_existing_equipment => 0 ) )
                    {
                        # Equip was successful, so don't try to equip again
                        no warnings;
                        last LOOP;
                    }
                };
                catch {
                    if ( $_ !~ /Can't equip an item of that type there/ ) {
                        croak $_;
                    }
                };
            }
        }
    }
    
    $character->add_item_to_grid($self, $grid_loc) if ! $self->equipped;

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
	my %params = @_;
	
	my $combat = $params{combat} // 0;
	my $is_equipped = $params{is_equipped} // $self->equipped;
	my $character = $params{character};
	
	return @{$self->{_actions}{$combat}} if $self->{_actions}{$combat}; 
	
	my @enchantments = $self->item_enchantments;
	
	my @actions;
	foreach my $enchantment (@enchantments) {
		next unless $enchantment->is_usable($combat);
		if ($enchantment->must_be_equipped) {
			push @actions, $enchantment if $is_equipped;
		}
		else {
			push @actions, $enchantment;
		}
	}
	
	if ($self->item_type->usable) {
	    if (! $self->can('is_usable')) {
	        # It's possible that this could be called before any roles have been applied
	        #  (i.e. during insertion). In this case, we just want to return, i.e. we don't
	        #  know if the item can be used now, so we don't try to work it out, and make
	        #  sure we don't save the result into the cache.
	        return;
	    }
	    	        
        push @actions, $self if $self->is_usable($combat, $character);   
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
		
		$quest->terminate(
            party_message => $message
		);
		$quest->update;
	}

}

sub _apply_role {
	my $self = shift;
	
	my $role = $self->get_role_name;

	return unless $role;
	
	my $failed = try {
	   $self->ensure_class_loaded($role);
	}
	catch {
	    return 1 if /Can't locate/;
	    
	    die $_;
	};
	
	return if $failed;
		
	$role->meta->apply($self);	
}

sub get_role_name {
	my $self = shift;
	
	my $name = $self->item_type->item_type;
	
	$name =~ s/ /_/g;
	
	return 'RPG::Schema::Role::Item_Type::' . $name;
}

sub repair {
    my $self = shift;
    
	my $variable_rec = $self->variable_row('Durability');
	$variable_rec->item_variable_value( $variable_rec->max_value );
	$variable_rec->update;
	
	my $character = $self->belongs_to_character;
    $character->calculate_attack_factor;
    $character->calculate_defence_factor;
    $character->update;		       
}

sub start_sector {
    my $self = shift;
    
    my $sector = $self->find_related('grid_sectors',
        {
            start_sector => 1,
        }
    );
    
    return $sector;   
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);


1;
