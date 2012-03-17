package RPG::Schema::Building_Upgrade;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Building_Upgrade');

__PACKAGE__->add_columns(qw/upgrade_id building_id type_id/);

__PACKAGE__->add_columns( 
	level => { accessor => '_level' },
	damage => { accessor => '_damage' },
	damage_last_done => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key(qw/upgrade_id/);

__PACKAGE__->belongs_to( 'type', 'RPG::Schema::Building_Upgrade_Type', 'type_id' );
__PACKAGE__->belongs_to( 'building', 'RPG::Schema::Building', 'building_id' );

sub insert {
	my ( $self, @args ) = @_;
	
	$self->next::method(@args);
	
	$self->_character_benefit_trigger;	
	
	return $self;
}

sub level {
    my $self = shift;
    my $new_level = shift;
    
    if (defined $new_level) {
        $self->_level($new_level);
        $self->_character_benefit_trigger;
    }
    
    return $self->_level;
}

sub damage {
    my $self = shift;
    my $new_damage = shift;
    
    if (defined $new_damage) {
        if ($new_damage > $self->_level) {
            $new_damage = $self->_level;
        }
        
        $self->_damage($new_damage);
        $self->_character_benefit_trigger;
    }
    
    return $self->_damage;   
}

sub effective_level {
    my $self = shift;
    
    return $self->level - $self->damage;   
}

# If the level of the upgrade has changed, make sure all characters in the 
#  building have their stats (AF,DF, etc) calculated correctly
sub _character_benefit_trigger {
    my $self = shift;
    
    my $bonus = $self->type->bonus;

    return unless $bonus;
    
    my $building = $self->building;
        
    my $group;
    
    if ($building->owner_type eq 'town') {
        my $town = $building->owner;
        
        my $mayor = $town->mayor;
        
        return unless $mayor;
        
        $group = $mayor->creature_group;
    }
    else {
        $group = $self->result_source->schema->resultset('Garrison')->find(
            {
                land_id => $building->land_id,
            }
        );
    }

    return unless $group;
    
    my $method = "calculate_$bonus";
    
    foreach my $character ($group->members) {
        next unless $character->is_character;
  
        $character->$method(
            {
                # Have to pass this in, since it may not have been written to the DB yet
                bonus_level => {
                    $bonus => $self->_level - ($self->_damage // 0),
                }
            }
        );
        $character->update;
    }
}

1;
