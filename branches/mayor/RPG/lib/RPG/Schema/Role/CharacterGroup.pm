package RPG::Schema::Role::CharacterGroup;

use Moose::Role;

use Carp;

requires qw/members flee_threshold in_combat is_online end_combat name/;

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

# Award XP to all characters. Takes the amount of xp to award if it's the same for everyone, or a hash of
#  character id to amount awarded
# Returns an array with the details of the changes
sub xp_gain {
    my ( $self, $awarded_xp ) = @_;

    my @characters = $self->members;

    my @details;

    foreach my $character (@characters) {
        next if $character->is_dead;

        my $xp_gained = ref $awarded_xp eq 'HASH' ? $awarded_xp->{ $character->id } : $awarded_xp;
        
        next if ! $xp_gained || $xp_gained <= 0;

        my $level_up_details = $character->xp( $character->xp + ($xp_gained || 0) );

        push @details, {
        	character         => $character,	
			xp_awarded       => $xp_gained,
            level_up_details => $level_up_details,
        };

        $character->update;
    }

    return @details;
}

1;