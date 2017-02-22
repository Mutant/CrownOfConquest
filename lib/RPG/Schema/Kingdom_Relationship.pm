package RPG::Schema::Kingdom_Relationship;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Kingdom_Relationship');

__PACKAGE__->add_columns(qw/relationship_id kingdom_id with_id begun ended type/);

__PACKAGE__->set_primary_key('relationship_id');

__PACKAGE__->belongs_to( 'with_kingdom', 'RPG::Schema::Kingdom', { 'foreign.kingdom_id' => 'self.with_id' } );
__PACKAGE__->belongs_to( 'begun', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.begun' } );

sub reciprocal_type {
    my $self = shift;

    my $recip_relationship = $self->result_source->schema->resultset('Kingdom_Relationship')->find(
        {
            kingdom_id => $self->with_id,
            with_id    => $self->kingdom_id,
            ended      => undef,
        }
    );

    return $recip_relationship ? $recip_relationship->type : 'neutral';
}

1;
