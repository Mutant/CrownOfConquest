package RPG::NewDay::Action::Party;

use Mouse;

extends 'RPG::NewDay::Base';

sub depends { qw/RPG::NewDay::Action::CreateDay/ };

sub run {
    my $self = shift;
    my $context = $self->context;

    my $party_rs = $context->schema->resultset('Party')->search(
        {
            created => {'!=',undef},
            defunct => undef,
        },
        { prefetch => 'characters' }
    );

    while ( my $party = $party_rs->next ) {
        $party->new_day($context->current_day);
    }
}

1;
