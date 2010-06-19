package RPG::V::TT;

use strict;
use base 'Catalyst::View::TT';
use Carp;

use HTML::FillInForm;
use Data::Dumper;

#__PACKAGE__->config->{DEBUG} = 'all';
__PACKAGE__->config(TIMER => 1);

sub process {
    my ($self, $c, $params) = @_;

    croak "No template supplied" unless $params->{template};

    $params->{params}{error} ||= $c->stash->{error};
    $params->{params}{error} =~ s/'/\\\'/g if $params->{params}{error};
    
    my %old_stash = %{$c->stash};

    %{$c->stash} = (%{$c->req->params}, %{$params->{params}});
    $c->stash->{template} = $params->{template};
    $c->stash->{parties_online} = $old_stash{parties_online};

    $self->SUPER::process($c);
    
    if ($params->{fill_in_form}) {
        my $fif = new HTML::FillInForm;
        my $output = $c->res->body;

        my %fill_params = (%{$c->req->params}, %{$params->{params}});
        
        %fill_params = (%fill_params, %{$params->{fill_in_form}})
        	if ref $params->{fill_in_form} eq 'HASH';

        my $filled_output = $fif->fill(
            scalarref => \$output,
            fdat => \%fill_params,
        );

        $c->res->body($filled_output);
    }

    $c->stash(\%old_stash);
    
    if ($params->{return_output}) {
        my $output = $c->res->body;
        $c->res->body(undef);
        return $output;
    }    
}

1;
