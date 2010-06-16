package RPG::NewDay::Action::Party;

use Moose;

extends 'RPG::NewDay::Base';

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Enchantment/ };

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
