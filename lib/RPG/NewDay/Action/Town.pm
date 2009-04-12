package RPG::NewDay::Action::Town;

use Mouse;

extends 'RPG::NewDay::Base';

sub run {
    my $self = shift;
    my $context = $self->context;

    # Clear all tax paid
    $context->schema->resultset('Party_Town')->search->update({tax_amount_paid_today => 0});
}

1;