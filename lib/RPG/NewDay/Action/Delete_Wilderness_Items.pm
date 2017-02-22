package RPG::NewDay::Action::Delete_Wilderness_Items;

use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;

sub run {
    my $self = shift;

    my @items = $self->context->schema->resultset('Items')->search(
        {
            land_id => { '!=', undef },
        }
    );

    my $count = 0;
    foreach my $item (@items) {
        if ( Games::Dice::Advanced->roll('1d100') < 3 ) {
            $item->delete;
            $count++;
        }
    }

    $self->context->logger->debug( "Deleted $count of " . scalar @items . " wilderness items" );
}
