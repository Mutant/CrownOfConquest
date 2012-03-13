package RPG::NewDay::Action::Detonate;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my @bombs = $c->resultset('Bomb')->search(
        {
            planted => {'<=', DateTime->now->subtract( minutes => 5 )},
        }
    );
    
    my %party_msgs;
    foreach my $bomb (@bombs) {
        $bomb->detonate;
        $party_msgs{$bomb->party_id}++;   
    }
}

1;