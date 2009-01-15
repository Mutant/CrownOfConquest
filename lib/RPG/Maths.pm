use strict;
use warnings;

package RPG::Maths;

use Games::Dice::Advanced;

use Data::Dumper;

# Returns a random number with a weighting given to the lower numbers
#  The numbers to be chosen from must be passed in an array
sub weighted_random_number {
    my $package = shift;
    my @numbers = sort {$a <=> $b} @_;
    
    my $size_of_group = scalar @numbers;
    
    my $base_chance_per_number = int 100 / $size_of_group;
    
    # Count starts at 0 for odd number of numbers, 0.5 for even number of numbers
    #  This makes sure the cumulative chance adds to 100 
    my $count = 1; #scalar @numbers % 2 == 0 ? 0.5 : 0;
    my $cumulative_chance = 0;
    
    my %chances;
    foreach my $number (@numbers) {
        $count++;
        my $chance = $base_chance_per_number + ($base_chance_per_number / 2) * ($size_of_group - ($count-1));
        
        #warn "$number => $chance\n";
        
        $cumulative_chance+=$chance;
        
        $chances{$cumulative_chance} = $number;
    }
    
    #warn Dumper \%chances;
    
    my $roll = Games::Dice::Advanced->roll("1d" . $cumulative_chance);
    #warn $roll;
    
    foreach my $chance_to_check (sort {$a <=> $b} keys %chances) {
        #warn $chance_to_check;
        if ($roll <= $chance_to_check) {
            return $chances{$chance_to_check};
        }
    }
}

1;