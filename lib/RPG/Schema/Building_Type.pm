package RPG::Schema::Building_Type;
use base 'DBIx::Class';

use Moose;

with 'RPG::Schema::Role::ResourceConsumer';

use Carp;
use Math::Round qw(round);

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Building_Type');


__PACKAGE__->add_columns(
    'building_type_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'building_type_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'name',
      'is_nullable' => 0,
      'size' => '100'
    },
    'class' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'class',
      'is_nullable' => 0,
      'size' => '11'
    },
    'level' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'level',
      'is_nullable' => 0,
      'size' => '11'
    },
    'defense_factor' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'defense_factor',
      'is_nullable' => 0,
      'size' => '11'
    },
    'commerce_factor' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'commerce_factor',
      'is_nullable' => 0,
      'size' => '11'
    },
    'clay_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'clay_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'stone_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'stone_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'wood_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'wood_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'iron_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'iron_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'labor_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'labor_needed',
      'is_nullable' => 0,
      'size' => '11'
    },  
    'labor_to_raze' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'labor_to_raze',
      'is_nullable' => 0,
      'size' => '11'
    },
    'visibility' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '1',
      'is_foreign_key' => 0,
      'name' => 'visibility',
      'is_nullable' => 0,
      'size' => '11'
    }, 
    'image' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'image',
      'is_nullable' => 0,
      'size' => '11'
    },    
    'constr_image' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'constr_image',
      'is_nullable' => 0,
      'size' => '11'
    },
    'land_claim_range' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '1',
      'is_foreign_key' => 0,
      'name' => 'land_claim_range',
      'is_nullable' => 0,
      'size' => '11'
    },        
    'max_upgrade_level' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '1',
      'is_foreign_key' => 0,
      'name' => 'max_upgrade_level',
      'is_nullable' => 0,
      'size' => '11'
    },     
);
__PACKAGE__->set_primary_key('building_type_id');

sub attribute {
	my $self = shift;
	my $attribute = shift;

	my @attributes = $self->item_attributes;

	my ($item_attribute) = grep { $_->item_attribute_name->item_attribute_name eq $attribute } @attributes;	
			
	return $item_attribute;
}

sub variable_param {
	my $self = shift;
	my $variable = shift;
	
	my @params = $self->item_variable_params;
	my ($param) = grep { $_->item_variable_name->item_variable_name eq $variable } @params;
	
	return $param;
}

sub label {
    my $self = shift;
    
    return $self->name;
}

 sub turns_needed {
     my $self = shift;
     my $party = shift;
     
     return round $self->labor_needed / $party->characters_in_party->count;   
}

sub enough_resources {
    my $self = shift;
    my $build_groups = shift;
    my %resources = @_;
    
    my %resources_needed = $self->cost_to_build($build_groups);
    
    my $enough = 1;
    foreach my $resource (keys %resources) {
        my $needed = $resources_needed{$resource};
        
        if ($resources{$resource} < $needed) {
            $enough = 0;
            last;
        }
    }
    
    return $enough;       
}

sub cost_to_build {
    my $self = shift;
    my $build_groups = shift;
    
    my %resources_needed = (
       'Clay'  => $self->clay_needed,
       'Iron'  => $self->iron_needed,
       'Wood'  => $self->wood_needed,
       'Stone' => $self->stone_needed,
    );
	
    if ($build_groups) {        
        my $construction_bonus = 0;
        
        foreach my $build_group (@$build_groups) {
            $construction_bonus += $build_group->skill_aggregate('Construction', 'building_cost');
        }

        $construction_bonus = 50 if $construction_bonus > 50;
	   
        foreach my $res (keys %resources_needed) {
            $resources_needed{$res} = int $resources_needed{$res} * (1-($construction_bonus/100));            
        }
	}
	
	return %resources_needed
}


sub enough_turns {
    my $self = shift;
    my $party = shift;
    
    return $party->turns >= $self->turns_needed($party) ? 1 : 0;
}

sub turns_to_raze {
    my $self = shift;
    my $party = shift;
    
    return $self->labor_to_raze; 
}

1;
