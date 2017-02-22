package RPG::Schema::Kingdom_Claim;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Kingdom_Claim');

__PACKAGE__->add_columns(qw/claim_id kingdom_id character_id outcome/);

__PACKAGE__->add_columns(
    claim_made => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key('claim_id');

__PACKAGE__->belongs_to( 'kingdom',  'RPG::Schema::Kingdom',   'kingdom_id' );
__PACKAGE__->belongs_to( 'claimant', 'RPG::Schema::Character', 'character_id' );
__PACKAGE__->has_many( 'responses', 'RPG::Schema::Kingdom_Claim_Response', 'claim_id' );

sub response_from_party {
    my $self  = shift;
    my $party = shift;

    my $response_rec = $self->find_related(
        'responses',
        {
            party_id => $party->id,
        }
    );

    return $response_rec && $response_rec->response;
}

sub response_summary {
    my $self = shift;

    my %summary;
    foreach my $response_type (qw/support oppose/) {
        $summary{$response_type} = $self->search_related(
            'responses',
            {
                response => $response_type,
            }
        )->count;
    }

    return %summary;
}

sub days_left {
    my $self = shift;

    my $dur = $self->claim_made->subtract_datetime( DateTime->now()->subtract( days => RPG::Schema->config->{claim_wait_period} ) );

    return $dur->in_units('days');
}

1;
