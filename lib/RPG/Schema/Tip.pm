package RPG::Schema::Tip;
use base 'DBIx::Class';
use strict;
use warnings;

use Text::Wrap;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Tip');

__PACKAGE__->add_columns(qw/tip_id tip title /);

__PACKAGE__->set_primary_key(qw/tip_id/);

sub wrapped_tip {
    my $self = shift;

    $Text::Wrap::columns = 80;
    my $tip_text = $self->tip;

    return Text::Wrap::wrap( '', '<br>', $tip_text );
}

1;
