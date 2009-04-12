use strict;
use warnings;

package RPG::Schema::Town;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Town');

__PACKAGE__->resultset_class('RPG::ResultSet::Town');

__PACKAGE__->add_columns(qw/town_id town_name land_id prosperity blacksmith_age blacksmith_skill/);

__PACKAGE__->set_primary_key('town_id');

__PACKAGE__->has_many( 'shops', 'RPG::Schema::Shop', { 'foreign.town_id' => 'self.town_id' }, );

__PACKAGE__->has_many( 'quests', 'RPG::Schema::Quest', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->has_many( 'party_town', 'RPG::Schema::Party_Town', { 'foreign.town_id' => 'self.town_id' }, );

sub tax_cost {
    my $self  = shift;
    my $party = shift;

    my $party_town_rec = $self->find_related( 'party_town', { 'party_id' => $party->id, }, );

    if ( $party_town_rec && $party_town_rec->tax_amount_paid_today > 0 ) {
        return { paid => 1 };
    }

    my $base_cost = $self->prosperity * RPG::Schema->config->{tax_per_prosperity};

    my $multiplier = 1 + ( RPG::Schema->config->{tax_level_modifier} * ( $party->level - 1 ) );

    my $gold_cost = int $base_cost * $multiplier;

    my $turn_cost = int $gold_cost / RPG::Schema->config->{tax_turn_divisor};

    $turn_cost = 1 if $turn_cost < 1;

    return {
        gold  => $gold_cost,
        turns => $turn_cost,
    };

}

1;
