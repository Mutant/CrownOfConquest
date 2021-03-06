package RPG::V::TT;

use strict;
use base 'Catalyst::View::TT';
use Carp;

use HTML::FillInForm;
use Data::Dumper;

#__PACKAGE__->config->{DEBUG} = 'all';

use Template::Provider::Preload;

__PACKAGE__->config(
    ( RPG->config->{dev} ? () : (
            LOAD_TEMPLATES => [
                Template::Provider::Preload->new(
                    PRECACHE     => 1,
                    PREFETCH     => '*.html',
                    INCLUDE_PATH => RPG->path_to('root'),
                    COMPILE_DIR  => "/tmp/template_cache",
                ),
            ],
          ) ),
);

sub process {
    my ( $self, $c, $params ) = @_;

    croak "No template supplied" unless $params->{template};

    $params->{params}{error} ||= $c->stash->{error};
    $params->{params}{error} =~ s/'/\\\'/g if $params->{params}{error};

    my %old_stash = %{ $c->stash };

    %{ $c->stash } = ( %{ $c->req->params }, %{ $params->{params} } );
    $c->stash->{template} = $params->{template};

    $self->SUPER::process($c);

    if ( $params->{fill_in_form} ) {
        my $fif    = new HTML::FillInForm;
        my $output = $c->res->body;

        my %fill_params = ( %{ $c->req->params }, %{ $params->{params} } );

        %fill_params = ( %fill_params, %{ $params->{fill_in_form} } )
          if ref $params->{fill_in_form} eq 'HASH';

        my $filled_output = $fif->fill(
            scalarref => \$output,
            fdat      => \%fill_params,
        );

        $c->res->body($filled_output);
    }

    $c->stash( \%old_stash );

    if ( $params->{return_output} ) {
        my $output = $c->res->body;
        $c->res->body(undef);
        return $output;
    }
}

1;
