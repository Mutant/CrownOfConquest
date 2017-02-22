use strict;
use warnings;

package RPG::Template;

use Template;

sub process {
    my $self     = shift;
    my $config   = shift;
    my $template = shift;
    my $params   = shift;

    my $tt = Template->new(
        {
            INCLUDE_PATH       => $config->{home} . '/root',
            EVAL_PERL          => 0,
            TEMPLATE_EXTENSION => '',

            #COMPILE_DIR => "/tmp/template_cache",
        }
    ) || die $Template::ERROR, "\n";

    my $result;
    $tt->process( $template, $params, \$result )
      || die $tt->error(), "\n";

    return $result;
}

1;
