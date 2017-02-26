use strict;
use warnings;

package RPG::ResultSet::Land;

use base 'DBIx::Class::ResultSet';

use Carp;
use Data::Dumper;

use RPG::Map;
use RPG::ResultSet::RowsInSectorRange;

sub get_x_y_range {
    my ($self) = @_;

    my $range_rec = $self->find(
        {},
        {
            select => [ { min => 'x' }, { min => 'y' }, { max => 'x' }, { max => 'y' }, ],
            as => [qw/min_x min_y max_x max_y/],
        },
    );

    return (
        min_x => $range_rec->get_column('min_x') // 0,
        min_y => $range_rec->get_column('min_y') // 0,
        max_x => $range_rec->get_column('max_x') // 0,
        max_y => $range_rec->get_column('max_y') // 0,
    );
}

sub search_for_adjacent_sectors {
    my $self                  = shift;
    my $x                     = shift;
    my $y                     = shift;
    my $search_range          = shift;
    my $max_range             = shift;
    my $exclude_cgs_and_towns = shift // 0;    #/

    my %params;
    my %attrs;
    if ($exclude_cgs_and_towns) {
        $params{'creature_group.creature_group_id'} = undef;
        $params{'town.town_id'}                     = undef;
        $attrs{join} = [ 'creature_group', 'town' ];
    }

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset    => $self,
        relationship => 'me',
        base_point   => {
            x => $x,
            y => $y,
        },
        search_range        => $search_range,
        increment_search_by => 1,
        max_range           => $max_range,
        criteria            => \%params,
        attrs               => \%attrs,
    );
}

sub get_party_grid {
    my $self = shift;

    my %params = @_;

    my $dbh = $self->result_source->schema->storage->dbh;

    #$dbh->trace(2);

    my $sql = <<SQL;
SELECT me.land_id, me.x, me.y, me.terrain_id, ( (x >= ? and x <= ?) and (y >= ? and y <= ?) and (x!=? or y!=?) ) as next_to_centre,
    me.variation, tileset.prefix, terrain.image, terrain.terrain_id, terrain.terrain_name, terrain.modifier, mapped_sector.mapped_sector_id,
    mapped_sector.known_dungeon, town.town_id, town.town_name, town.prosperity, kingdom.name as kingdom_name

    FROM Land me
    JOIN Terrain terrain ON ( terrain.terrain_id = me.terrain_id )
    JOIN Map_Tileset tileset ON ( tileset.tileset_id = me.tileset_id )
    JOIN Mapped_Sectors mapped_sector ON ( mapped_sector.land_id = me.land_id and mapped_sector.party_id = ? )
    LEFT JOIN Town town ON ( town.land_id = me.land_id )
    LEFT JOIN Kingdom kingdom ON ( me.kingdom_id = kingdom.kingdom_id )
    WHERE ( x >= ? AND x <= ? AND y >= ? AND y <= ? )
SQL

    my @query_params = (
        $params{centre_point}->{x} - 1, $params{centre_point}->{x} + 1, $params{centre_point}->{y} - 1, $params{centre_point}->{y} + 1,
        $params{centre_point}->{x}, $params{centre_point}->{y}, $params{party_id}, $params{start_point}->{x},
        $params{end_point}->{x}, $params{start_point}->{y}, $params{end_point}->{y},
    );

    #warn "get_party_grid: $sql\n";
    #warn join( ',', @query_params ) . "\n";

    my $result = $dbh->selectall_arrayref( $sql, { Slice => {} }, @query_params, );

    return $result;
}

sub get_admin_grid {
    my $self = shift;

    my %params = @_;

    my $dbh = $self->result_source->schema->storage->dbh;

    my $sql = <<SQL;
SELECT *, orb.level as orb_level FROM Land me
    LEFT JOIN Town town ON ( town.land_id = me.land_id )
    LEFT JOIN Creature_Group creature_group ON ( creature_group.land_id = me.land_id )
    LEFT JOIN Creature_Orb orb ON ( orb.land_id = me.land_id )
SQL

    my $result = $dbh->selectall_arrayref( $sql, { Slice => {} }, (), );

    my $sql2 = <<SQL;
    select creature_group_id, round(avg(level)) as cg_level
    from Creature_Group join Creature using (creature_group_id)
    join Creature_Type using (creature_type_id) group by creature_group_id;
SQL

    my %cg_levels = map { $_->{creature_group_id} => $_->{cg_level} } @{ $dbh->selectall_arrayref( $sql2, { Slice => {} }, (), ) };

    foreach my $row (@$result) {
        $row->{cg_level} = $cg_levels{ $row->{creature_group_id} || '' };
    }

    return $result;

}

1;
