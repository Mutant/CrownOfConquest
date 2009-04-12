use strict;
use warnings;

package RPG::NewDay::Template;

use Template;

sub process {
    my $self     = shift;
    my $context  = shift;
    my $template = shift;
    my $params   = shift;

    my $tt = Template->new(
        {
            INCLUDE_PATH       => $context->config->{home} . '/root',
            EVAL_PERL          => 0,
            TEMPLATE_EXTENSION => '',
        }
    ) || die $Template::ERROR, "\n";

    my $result;
    $tt->process( $template, $params, \$result )
        || die $tt->error(), "\n";

    return $result;
}

1;
