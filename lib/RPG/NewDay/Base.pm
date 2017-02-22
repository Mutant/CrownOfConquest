# Base class for NewDay module. Provides a method for getting/setting the new day context as class data

package RPG::NewDay::Base;

use Moose;

has 'context' => ( is => 'rw', isa => 'RPG::NewDay::Context' );

sub cron_string {
    my $self = shift;

    return $self->context->config->{default_cron_string};
}

# If true, the other actions will keep processing if the current one returns an error
sub continue_on_error {
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
