use strict;
use warnings;
  
package RPG::ResultSet::Land;
  
use base 'DBIx::Class::ResultSet';

use Carp;
use Data::Dumper;

use RPG::Map;

sub get_x_y_range {
	my ($self) = @_;

    my $range_rec = $self->find(
		{},
		{
			select => [
				{ min => 'x' },
				{ min => 'y' },
				{ max => 'x' },
				{ max => 'y' },
			],
			as => [qw/min_x min_y max_x max_y/],
		},					
	);
	
	return (
		min_x => $range_rec->get_column('min_x'),
		min_y => $range_rec->get_column('min_y'),
		max_x => $range_rec->get_column('max_x'),
		max_y => $range_rec->get_column('max_y'),
	);
}

sub get_party_grid {
	my $self = shift;	
	
	my %params = @_;
	
	my $dbh = $self->result_source->schema->storage->dbh;
	#$dbh->trace(2);

	my $sql = <<SQL;
SELECT me.land_id, me.x, me.y, me.terrain_id, me.creature_threat, ( (x >= ? and x <= ?) and (y >= ? and y <= ?) and (x!=? or y!=?) ) as next_to_centre, 
	terrain.terrain_id, terrain.terrain_name, terrain.image, terrain.modifier, mapped_sector.mapped_sector_id, mapped_sector.storage_type, 
	mapped_sector.party_id, mapped_sector.date_stored, town.town_id, town.town_name, town.prosperity 
	
	FROM Land me  
	JOIN Terrain terrain ON ( terrain.terrain_id = me.terrain_id ) 
	LEFT JOIN Mapped_Sectors mapped_sector ON ( mapped_sector.land_id = me.land_id and mapped_sector.party_id = ? ) 
	LEFT JOIN Town town ON ( town.land_id = me.land_id ) 
	WHERE ( x >= ? AND x <= ? AND y >= ? AND y <= ? )
SQL
	
	my @query_params = (
		$params{centre_point}->{x}-1,
		$params{centre_point}->{x}+1,
		$params{centre_point}->{y}-1,
		$params{centre_point}->{y}+1,
		$params{centre_point}->{x},
		$params{centre_point}->{y},				
		$params{party_id},
		$params{start_point}->{x}, 
		$params{end_point}->{x},
		$params{start_point}->{y},
		$params{end_point}->{y},
	);
	
	warn "get_party_grid: $sql\n";
	warn join (',',@query_params) . "\n";
	
	my $result = $dbh->selectall_arrayref( 
		$sql,
		{ Slice => {} }, 
		@query_params,
	);
	
	return $result;
}

1;