package RPG::Schema::Mapped_Sectors;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Mapped_Sectors');

__PACKAGE__->add_columns(qw/mapped_sector_id storage_type land_id party_id/);

__PACKAGE__->add_columns(
	date_stored => { data_type => 'datetime' }
);

__PACKAGE__->set_primary_key('mapped_sector_id');

1;