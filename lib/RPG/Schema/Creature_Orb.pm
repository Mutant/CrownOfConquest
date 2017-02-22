package RPG::Schema::Creature_Orb;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Creature_Orb');

__PACKAGE__->add_columns(qw/creature_orb_id level land_id name/);

__PACKAGE__->resultset_class('RPG::ResultSet::Creature_Orb');

__PACKAGE__->set_primary_key(qw/creature_orb_id/);

__PACKAGE__->belongs_to(
    'land',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

# Returns true if the party level supplied is high enough to destroy the orb
sub can_destroy {
    my $self        = shift;
    my $party_level = shift;

    return 1 if $party_level >= $self->level * RPG::Schema->config->{orb_level_multiplier_to_destroy_orb};
}

1;
