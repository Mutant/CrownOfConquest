package RPG::Schema::Garrison;

use Moose;

extends 'DBIx::Class';

with 'RPG::Schema::Role::BeingGroup';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Garrison');

__PACKAGE__->add_columns(qw/garrison_id land_id party_id/);

__PACKAGE__->set_primary_key('garrison_id');

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', 'garrison_id', {cascade_delete => 0});

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id', );

sub members {
	my $self = shift;
	
	return $self->characters;	
}

sub number_alive {
    my $self = shift;

    return $self->result_source->schema->resultset('Character')->count(
        {
            hit_points => { '>', 0 },
            garrison_id   => $self->id,
        }
    );
}

sub after_land_move {
    my $self = shift;
    my $land = shift;
}

1;