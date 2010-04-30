package RPG::Schema::Role::CharacterGroup;

use Moose::Role;

use Carp;

requires qw/members flee_threshold in_combat/;

use List::Util qw(sum);
use POSIX;
use Carp;

sub level {
    my $self = shift;

    my (@characters) = $self->members;
    
    return 0 unless @characters;
    
    return $characters[0]->level if scalar @characters == 1;

    return int _median( map { $_->level } @characters );
}

# TODO: use something from CPAN
sub _median {
    sum( ( sort { $a <=> $b } @_ )[ int( $#_ / 2 ), ceil( $#_ / 2 ) ] ) / 2;
}

sub is_over_flee_threshold {
    my $self = shift;

    my $rec = $self->find_related(
        'characters',
        {},
        {
            select => [ { sum => 'max_hit_points' }, { sum => 'hit_points' }, ],
            'as'   => [ 'total_hps', 'current_hps' ],
        }
    );

    my $percentage = int( ( $rec->get_column('current_hps') / $rec->get_column('total_hps') ) * 100 );

    return $percentage < $self->flee_threshold ? 1 : 0;
}


1;