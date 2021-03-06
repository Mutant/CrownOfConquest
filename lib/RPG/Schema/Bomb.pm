package RPG::Schema::Bomb;
use base 'DBIx::Class';
use strict;
use warnings;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use DateTime;
use RPG::Map;
use Math::Round qw(round);

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Bomb');

__PACKAGE__->add_columns(qw/bomb_id land_id dungeon_grid_id party_id level/);

__PACKAGE__->add_columns(
    planted   => { data_type => 'datetime' },
    detonated => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key(qw/bomb_id/);

__PACKAGE__->belongs_to( 'land', 'RPG::Schema::Land', 'land_id' );
__PACKAGE__->belongs_to( 'dungeon_grid', 'RPG::Schema::Dungeon_Grid', 'dungeon_grid_id' );

sub detonate {
    my $self = shift;

    my @buildings;
    my $detonation_bonus = 0;
    if ( $self->dungeon_grid_id ) {
        my $dungeon = $self->dungeon_grid->dungeon_room->dungeon;
        if ( $dungeon->type eq 'castle' ) {
            my $building = $self->result_source->schema->resultset('Building')->find(
                {
                    land_id => $dungeon->land_id,
                }
            );

            if ($building) {

                push @buildings, $building;

                my $stairs_sector = $dungeon->stairs_sector;

                my $distance_to_stairs = RPG::Map->get_distance_between_points(
                    {
                        x => $stairs_sector->x,
                        y => $stairs_sector->y,
                    },
                    {
                        x => $self->dungeon_grid->x,
                        y => $self->dungeon_grid->y,
                    }
                );

                $detonation_bonus = round( $distance_to_stairs / 3 ) - 3;
            }
        }
    }
    else {
        @buildings = $self->land->get_adjacent_buildings(1);
    }

    my $perm_damage_chance = $self->level / 5 + $detonation_bonus;
    my $temp_damage_chance = $self->level * 2 + $detonation_bonus;

    my @damaged_upgrades;
    foreach my $building (@buildings) {
        my @upgrades = grep { $_->type->name =~ /^Rune/ && $_->effective_level > 0 } $building->upgrades;

        next unless @upgrades;

        foreach my $upgrade (@upgrades) {
            my $damage_type;

            my $perm_roll = Games::Dice::Advanced->roll('1d100');
            my $temp_roll = Games::Dice::Advanced->roll('1d100');

            my %damage_done;

            if ( $perm_roll <= $perm_damage_chance ) {
                $upgrade->level( $upgrade->level - 1 );
                $damage_done{perm} = 1;
            }

            if ( $temp_roll <= $temp_damage_chance ) {
                my $damage_amount = Games::Dice::Advanced->roll('1d3');
                $upgrade->damage( $upgrade->damage + $damage_amount );
                $upgrade->damage_last_done( DateTime->now() );
                $damage_done{temp} = $damage_amount;
            }

            $upgrade->update;

            if (%damage_done) {
                push @damaged_upgrades, {
                    upgrade     => $upgrade,
                    damage_done => \%damage_done,
                  }
            }
        }
    }

    $self->detonated( DateTime->now() );
    $self->update;

    return @damaged_upgrades;
}

1;
