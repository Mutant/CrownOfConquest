# Base class for NewDay module. Provides a method for getting/setting the new day context as class data

package RPG::NewDay::Base;

use Moose;

has 'context' => (is => 'rw', isa => 'RPG::NewDay::Context');

sub cron_string {
    my $self = shift;
    
    return $self->context->config->{default_cron_string};   
}

__PACKAGE__->meta->make_immutable;

1;