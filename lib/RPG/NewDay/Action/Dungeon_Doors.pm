package RPG::NewDay::Action::Dungeon_Doors;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;
use Data::Dumper;

sub cron_string {
    my $self = shift;

    return $self->context->config->{dungeon_doors_cron_string};
}

sub run {
    my $self = shift;

    my $c = $self->context;

    my @doors = $c->schema->resultset('Door')->search(
        {
            type => { '!=', 'standard' },
            state => 'open',
        }
    );

    foreach my $door (@doors) {
        if ( Games::Dice::Advanced->roll('1d100') <= 60 ) {
            $door->state('closed');
            $door->update;
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;
