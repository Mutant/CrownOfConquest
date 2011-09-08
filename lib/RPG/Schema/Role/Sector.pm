package RPG::Schema::Role::Sector;

use Moose::Role;

requires qw/search_related/;

# Returns the creature group in this sector, if they're "available" (i.e. not on combat)
sub available_creature_group {
    my $self = shift;

    my $creature_group = $self->search_related(
        'creature_group',
        { 
        	'in_combat_with.party_id' => undef,
        },
        {
            prefetch => { 'creatures' => [ 'type', 'creature_effects' ] },
            join     => 'in_combat_with',
            order_by => 'type.creature_type, group_order',
        },
    )->first;

    return unless $creature_group;

    return $creature_group if $creature_group->number_alive > 0;

    return;
}

1;