use strict;
use warnings;

package RPG::Schema::Equip_Places;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Equip_Places');

__PACKAGE__->resultset_class('RPG::ResultSet::Equip_Places');

__PACKAGE__->add_columns(qw/equip_place_id equip_place_name/);

__PACKAGE__->set_primary_key('equip_place_id');

__PACKAGE__->has_many( 'equip_place_categories', 'RPG::Schema::Equip_Place_Category', { 'foreign.equip_place_id' => 'self.equip_place_id' } );

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', { 'foreign.equip_place_id' => 'self.equip_place_id' } );

__PACKAGE__->many_to_many(
    categories => 'equip_place_categories',
    'item_category'
);

my %OPPOSITE_HANDS = (
    'Left Hand'  => 'Right Hand',
    'Right Hand' => 'Left Hand',
);

sub opposite_hand {
    my $self = shift;

    return unless $OPPOSITE_HANDS{ $self->equip_place_name };

    my ($opposite_hand) =
        $self->result_source->schema->resultset('Equip_Places')->find( { equip_place_name => $OPPOSITE_HANDS{ $self->equip_place_name }, }, );

    return $opposite_hand;
}

1;
