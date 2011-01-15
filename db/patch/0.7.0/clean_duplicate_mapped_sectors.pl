#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $dbh = DBI->connect(@{$config->{'Model::DBIC'}{connect_info}});

my $sql = 'select m1.* from Mapped_Sectors m1 
				join Mapped_Sectors m2 on (m1.land_id = m2.land_id and m1.party_id = m2.party_id and m1.mapped_sector_id != m2.mapped_sector_id)';

my $sth = $dbh->prepare($sql);
$sth->execute;

my %found;

while (my $rec = $sth->fetchrow_hashref) {
	if ($found{$rec->{land_id} . '-' . $rec->{party_id}}) {
		#warn "Deleting mapped sector " . $rec->{mapped_sector_id};
		$dbh->do("delete from Mapped_Sectors where mapped_sector_id = " . $rec->{mapped_sector_id});
	}
	else {
		#warn "Found mapped sector " . $rec->{mapped_sector_id};
		$found{$rec->{land_id} . '-' . $rec->{party_id}} = 1;	
	}
}