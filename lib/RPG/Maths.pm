use strict;
use warnings;

package RPG::Maths;

use Games::Dice::Advanced;
use Math::Round qw(round);

use Data::Dumper;
use Carp;

# Returns a random number with a weighting given to the lower numbers
#  The numbers to be chosen from must be passed in an array
sub weighted_random_number {
    my $package = shift;
    my @numbers = sort {$a <=> $b} @_;
    
    return unless @numbers;    
    
	my ($cumulative_chance, %chances) = _calculate_weights(@numbers);
	    
    my $roll = Games::Dice::Advanced->roll("1d" . $cumulative_chance) // 0;
    my $res;            
    foreach my $chance_to_check (sort {$a <=> $b} keys %chances) {    
        if ($roll <= $chance_to_check) {
            $res = $chances{$chance_to_check};
            last;
        }
    }
    
    confess "Got no res (roll: $roll)" . Dumper \%chances unless defined $res;
    
    return $res;
}

sub _calculate_weights {
	my @numbers = @_;
	
    my $size_of_group = scalar @numbers;
    
    my $base_chance_per_number = $size_of_group * 100;
     
    my $count = int $size_of_group / 10;
    $count = 2 if $count < 2;
    my $cumulative_chance = 0;
    
    my %chances;
    foreach my $number (@numbers) {
        $count++;
        
        my $chance = $base_chance_per_number / $count**2;
        
        $cumulative_chance+=$chance;
        
        $chances{$cumulative_chance} = $number;
    }
    
    return (int($cumulative_chance), %chances);
}

# Random number between a max and min
sub roll_in_range {
	my $package = shift;
	my $min = shift // confess "min not provided";
	my $max = shift // confess "max not provided";
	
	my $dice_size = $max - $min + 1;
	
	my $roll = Games::Dice::Advanced->roll('1d' . $dice_size) + $min - 1;
	
	return $roll;
	
}

sub precentage_difference {
    my $package = shift;
    my $first_number = shift;
    my $second_number = shift;
    
    return ($first_number-$second_number)/(($first_number+$second_number)/2)*100;   
}

sub percentage_change {
    my $package = shift;
    my $first_number = shift;
    my $second_number = shift;
    
    return (($first_number-$second_number)/$first_number)*100;
}

1;