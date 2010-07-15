use strict;
use warnings;

package RPG::Schema::Town;

use base 'DBIx::Class';

use Carp;

use Math::Round qw(round);

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Town');

__PACKAGE__->resultset_class('RPG::ResultSet::Town');

__PACKAGE__->add_columns(qw/town_id town_name land_id prosperity blacksmith_age blacksmith_skill discount_type discount_value discount_threshold/);

__PACKAGE__->set_primary_key('town_id');

__PACKAGE__->has_many( 'shops', 'RPG::Schema::Shop', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->has_many( 'quests', 'RPG::Schema::Quest', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->has_many( 'party_town', 'RPG::Schema::Party_Town', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->might_have( 'castle', 'RPG::Schema::Dungeon', { 'foreign.land_id' => 'self.land_id' }, );

sub tax_cost {
    my $self  = shift;
    my $party = shift;

    my $party_town_rec = $self->find_related( 'party_town', { 'party_id' => $party->id, }, );

    if ( $party_town_rec && $party_town_rec->tax_amount_paid_today > 0 ) {
        return { paid => 1 };
    }
    
    my $prestige = 0;
    $prestige = $party_town_rec->prestige if $party_town_rec;

    my $base_cost = $self->prosperity * RPG::Schema->config->{tax_per_prosperity};

    my $multiplier = 1 + ( RPG::Schema->config->{tax_level_modifier} * ( $party->level - 1 ) );
    
    my $prestige_modifier = (0-$prestige) / 40;

    my $gold_cost = round $base_cost * ($multiplier + $prestige_modifier); 
    $gold_cost = 1 if $gold_cost < 1;

    my $turn_cost = round $gold_cost / RPG::Schema->config->{tax_turn_divisor};

    $turn_cost = 1 if $turn_cost < 1;

    return {
        gold  => $gold_cost,
        turns => $turn_cost,
    };
}

sub has_road_to {
    my $self = shift;
    my $dest_town = shift;
    
    my $found_town = 0;
    
    return $self->_find_roads($self->location, $dest_town->location);
}

sub _find_roads {
    my $self = shift;
    my $start_sector = shift;
    my $dest_sector = shift;
    my $checked = shift || {};
    
    $checked->{$start_sector->id} = 1;
        
    my @surround_sectors = $self->result_source->schema->resultset('Land')->search_for_adjacent_sectors(
        $start_sector->x,
        $start_sector->y,
        3,
        3,        
    );
        
    my @connected_sectors;
    foreach my $sector (@surround_sectors) {
        next if $checked->{$sector->id};
            
        if ($start_sector->has_road_joining_to($sector)) {            
            if ($sector->id == $dest_sector->id) {
                return 1;
            }
            
            push @connected_sectors, $sector;   
        }
    }
    
    foreach my $connected_sector (@connected_sectors) {
        return 1 if $self->_find_roads($connected_sector, $dest_sector, $checked);   
    }
    
    return 0;
}

1;
