package RPG::Schema::Role::Being;

use Moose::Role;

use Lingua::EN::Gender qw();
use List::Util qw(sum);
use Math::Round qw(round);

requires qw/group_id group effect_value resistances is_spell_caster check_for_auto_cast critical_hit_chance hit/;

sub health {
	my $self = shift;

    # Would be nice to 'require' the hit point methods in the role, but because they're auto-generated by DBIC (for at least some consumers),
    #  we can't.
	return $self->hit_points_current / $self->hit_points_max;
}

sub pronoun {
    my $self = shift;
    
    my $pronoun_type = shift;
    
    return Lingua::EN::Gender::pronoun($pronoun_type, $self->gender);    
}

# Return the number of attacks allowed by this character
sub number_of_attacks {
    my $self           = shift;

    # Modifier is number of extra attacks per round
    #  i.e. 1 = 2 attacks per round, 0.5 = 1 attacks every 2 rounds
    my $modifier       = shift;
    
    my @attack_history = @_;

    my $number_of_attacks = 1;

    # Check for any attack_frequency effects
    my $extra_modifier_from_effects = $self->effect_value('attack_frequency') || 0;
    $modifier += $extra_modifier_from_effects;

    # Any whole numbers are added on to number of attacks
    my $whole_extra_attacks = $modifier > 0 ? int $modifier : round $modifier;
    $number_of_attacks += $whole_extra_attacks;

    # Find out the decimal if any, and decide whether another attack should occur this round
    $modifier = $modifier - $whole_extra_attacks;

    # If there's a modifier, and an attack history exists, figure out if there should be another extra attack this round.
    #  (If there's no history, we start with the smaller amount of attacks)
    if ( $modifier != 0 && @attack_history ) {

        # Figure out number of attacks they should've had in recent rounds
        my $expected_attacks = int 1 / $modifier;

        # Figure out how far to look back
        my $lookback = $expected_attacks - 1;
        $lookback = scalar @attack_history if $lookback > scalar @attack_history;

        my @recent = splice @attack_history, -$lookback;

        my $count = sum @recent;

        if ( $count < $expected_attacks + $whole_extra_attacks * $lookback ) {
            $number_of_attacks++;
        }
    }

    return $number_of_attacks;
}

sub resistance {
   my $self = shift;
   my $type = shift;
   
   my %resist = $self->resistances;
   
   return $resist{$type}; 
}

# Hit being with chance of resistance.
#  Returns 1 if hit was resisted, 0 if being took damage 
sub hit_with_resistance {
    my $self = shift;
    my $type = shift;
    my $damage = shift;
    my $attacker = shift;
    my $effect_type = shift;
    
    return 1 if $self->resistance_roll($type);

    $self->hit($damage, $attacker, $effect_type);
    
    return 0;
}

sub resistance_roll {
    my $self = shift;
    my $type = shift;
    
    my $resistance_value = $self->resistance($type);
    
    $resistance_value = 90 if $resistance_value > 90; 
    
    confess "Can't find resistance value for $type" unless defined $resistance_value;
    
    if (Games::Dice::Advanced->roll('1d100') <= $resistance_value) {
        return 1;
    }
    
    return 0;    
    
}

1;