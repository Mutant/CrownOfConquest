use strict;
use warnings;

package Test::RPG::NewDay::ActionBase;

use base qw(Test::RPG::DB);

use Test::MockObject;

use Test::RPG::Builder::Day;

sub setup_context {
    my $self = shift;

    my $day = Test::RPG::Builder::Day->build_day( $self->{schema} );

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema',    $self->{schema} );
    $mock_context->set_always( 'config',    $self->{config} );
    $mock_context->set_always( 'yesterday', $day );
    $mock_context->set_always( 'logger',    $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    $self->{mock_context} = $mock_context;
}

1;