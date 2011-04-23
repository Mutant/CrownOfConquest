use strict;
use warnings;

package RPG::Schema::Day;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('`Day`');

__PACKAGE__->resultset_class('RPG::ResultSet::Day');

__PACKAGE__->add_columns(qw/day_id day_number game_year date_started turns_used/);

__PACKAGE__->set_primary_key('day_id');

sub difference_to_today {
    my $self = shift;
    
    my $today = $self->result_source->schema->resultset('Day')->find_today();
    
    my $diff = $self->day_number - $today->day_number;
    
    return $diff;
}

sub difference_to_today_str {    
    my $self = shift;
    
    my $diff = $self->difference_to_today;
    
    if ($diff == 1) {
        return 'tomorrow';   
    }
    elsif ($diff == -1) {
        return 'yesterday';
    }
    elsif ($diff > 0) {
        return "in $diff days";   
    }
    elsif ($diff < 0) {
        return abs($diff) . " days ago";   
    }
    else {
        return "today";
    }
}

1;