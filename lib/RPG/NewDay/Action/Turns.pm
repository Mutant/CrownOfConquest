package RPG::NewDay::Action::Turns;

use Moose;

extends 'RPG::NewDay::Base';

sub cron_string {
    my $self = shift;

    return $self->context->config->{new_turns_cron_string};
}

sub run {
    my $self = shift;

    my $context = $self->context;

    my $party_rs = $context->schema->resultset('Party')->search(
        {
            created => { '!=', undef },
            defunct => undef,
        },
    );

    while ( my $party = $party_rs->next ) {
        $party->increase_turns( $party->turns + RPG::Schema->config->{turns_per_hour} );
        $party->update;
    }
}

1;
