package RPG::Schema::Role::CharacterGroup;

use Moose::Role;

use Carp;

requires qw/members flee_threshold in_combat is_online end_combat display_name/;

use List::Util qw(sum shuffle);
use POSIX;
use Carp;
use Statistics::Basic qw(average);
use Try::Tiny;

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

    my ( $current_hp, $total_hp ) = ( 0, 0 );
    foreach my $character (@characters) {
        $current_hp += $character->hit_points;
        $total_hp   += $character->max_hit_points;
    }

    my $percentage = $total_hp != 0 ? ( $current_hp / $total_hp ) * 100 : 0;

    return $percentage < $self->flee_threshold ? 1 : 0;
}

sub give_item_to_character {
    my $self = shift;
    my $item = shift;

    my @characters = shuffle grep { !$_->is_dead } $self->members;

    @characters = sort { $b->encumbrance_left <=> $a->encumbrance_left } @characters;

    my $given_to;
  LOOP: foreach my $character (@characters) {
        try {
            $item->add_to_characters_inventory($character);
        }
        catch {
            if ( $_ =~ /^Couldn't find room for item/ ) {
                next LOOP;
            }

            die $_;
        };

        $given_to = $character;
        last;
    }

    return $given_to;
}

sub average_stat {
    my $self = shift;
    my $stat = shift;

    my @stats;
    foreach my $character ( $self->members ) {
        next if $character->is_dead;
        push @stats, $character->$stat;
    }

    return average @stats;
}

sub flee_chance {
    my $self          = shift;
    my $opponents     = shift;
    my $flee_attempts = shift // 0;

    my $level_difference = $opponents->level - $self->level;
    my $flee_chance =
      RPG::Schema->config->{base_flee_chance} + ( RPG::Schema->config->{flee_chance_level_modifier} * ( $level_difference > 0 ? $level_difference : 0 ) );

    my $opp_skill_benefit = $opponents->skill_aggregate( 'Tactics', 'opponent_flee' ) // 0;
    $flee_chance -= $opp_skill_benefit;

    my $skill_bonus = $self->skill_aggregate( 'Strategy', 'flee_bonus' ) // 0;
    $flee_chance += $skill_bonus;

    if ( $self->level == 1 ) {

        # Bonus chance for being low level
        $flee_chance += RPG::Schema->config->{flee_chance_low_level_bonus};
    }

    $flee_chance += ( RPG::Schema->config->{flee_chance_attempt_modifier} * $flee_attempts );
}

1;
