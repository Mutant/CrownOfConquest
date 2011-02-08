package RPG::Schema::Building;

use Moose;
use Data::Dumper;

extends 'DBIx::Class';

__PACKAGE__->load_components(qw/Core Numeric/);
__PACKAGE__->table('Building');

__PACKAGE__->resultset_class('RPG::ResultSet::Building');

__PACKAGE__->add_columns(qw/building_id land_id building_type_id owner_id owner_type name clay_needed stone_needed wood_needed iron_needed labor_needed/);

__PACKAGE__->numeric_columns(qw/clay_needed stone_needed wood_needed iron_needed labor_needed/);

__PACKAGE__->set_primary_key('building_id');

__PACKAGE__->belongs_to( 'building_type', 'RPG::Schema::Building_Type', 'building_type_id', {cascade_delete => 0} );

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' },
    {cascade_delete => 0}
);


sub upgrades_to {
	my $self = shift;
	return $self->{upgrades_to};
}
sub set_upgrades_to {
	my $self = shift;
	$self->{upgrades_to} = shift;
}

sub type {
	my $self = shift;
	return $self->{type};
}
sub set_type {
	my $self = shift;
	$self->{type} = shift;
}

sub class {
	my $self = shift;
	return $self->{'class'};
}
sub set_class {
	my $self = shift;
	$self->{class} = shift;
}

sub level {
	my $self = shift;
	return $self->{level};
}
sub set_level {
	my $self = shift;
	$self->{level} = shift;
}

sub image {
	my $self = shift;
	return $self->{image};
}
sub set_image {
	my $self = shift;
	$self->{image} = shift;
}


1;
