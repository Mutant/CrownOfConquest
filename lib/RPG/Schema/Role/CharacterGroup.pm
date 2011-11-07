package RPG::Schema::Role::CharacterGroup;

use Moose::Role;

use Carp;

requires qw/members flee_threshold in_combat is_online end_combat display_name/;

use List::Util qw(sum shuffle);
use POSIX;
use Carp;
use Statistics::Basic qw(average);

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

    my @characters = $self->members;
    
    my ($current_hp, $total_hp) = (0,0);
    foreach my $character (@characters) {
    	$current_hp += $character->hit_points;
    	$total_hp   += $character->max_hit_points;
    }

    my $percentage = $total_hp != 0 ? ( $current_hp / $total_hp ) * 100 : 0;

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


sub get_least_encumbered_character {
    my $self = shift;
    
    my @characters = shuffle grep { ! $_->is_dead } $self->members;
    
    @characters = sort { $b->encumbrance_left <=> $a->encumbrance_left } @characters;
    
    return $characters[0];
}

sub average_stat {
    my $self = shift;
    my $stat = shift;

    my @stats;
    foreach my $character ($self->members) {
        next if $character->is_dead;
        push @stats, $character->$stat;   
    }
    
    return average @stats;
}

sub flee_chance {
    my $self = shift;
    my $opponents = shift;
    my $flee_attempts = shift // 0;
    
	my $level_difference = $opponents->level - $self->level;
	my $flee_chance =
		RPG::Schema->config->{base_flee_chance} + ( RPG::Schema->config->{flee_chance_level_modifier} * ( $level_difference > 0 ? $level_difference : 0 ) );
		
    my $opp_skill_benefit = $opponents->skill_aggregate('Tactics', 'opponent_flee') // 0;
    $flee_chance -= $opp_skill_benefit;		

	if ( $self->level == 1 ) {
		# Bonus chance for being low level
		$flee_chance += RPG::Schema->config->{flee_chance_low_level_bonus};
	}

	$flee_chance += ( RPG::Schema->config->{flee_chance_attempt_modifier} * $flee_attempts );       
}

1;