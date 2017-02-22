package RPG::NewDay::Action::Effect;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;

sub run {
    my $self = shift;

    my $c = $self->context;

    my $effects_rs = $c->schema->resultset('Effect')->search(
        {
            time_type => 'day',
            time_left => { '>', 0 },
        },
    );

    while ( my $effect = $effects_rs->next ) {
        $effect->time_left( $effect->time_left - 1 );

        if ( $effect->time_left <= 0 ) {

            # TODO: could be other types of day effects (i.e. non party)
            $effect->party_effect->delete;
            $effect->delete;
        }
        else {
            $effect->update;
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;
