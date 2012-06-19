use strict;
use warnings;

package RPG::DateTime;

use DateTime;
use Lingua::EN::Inflect qw(PL_N);

sub time_since_datetime {
    my $self = shift;
    my $date_time = shift;
    my $prefix = shift // 1;
    
    return 'Never' unless $date_time;
    
    my $now = DateTime->now;
    my $dur = $date_time->subtract_datetime($now);

    my $str = $prefix ? "About " : '';
    if ($dur->years) {
        $str .= $dur->years . PL_N(" year", $dur->years);   
    }
    elsif ($dur->months) {
        $str .= $dur->months . PL_N(" month", $dur->months);   
    }
    elsif ($dur->weeks) {
        $str .= $dur->weeks . PL_N(" week", $dur->weeks);   
    }    
    elsif ($dur->days) {
        $str .= $dur->days . PL_N(" day", $dur->days);   
    }
    elsif ($dur->hours) {
        $str .= $dur->hours . PL_N(" hour", $dur->hours);   
    }
    elsif ($dur->minutes) {
        $str .= $dur->minutes . PL_N(" minute", $dur->minutes);   
    }
    elsif ($dur->seconds) {
        $str .= $dur->seconds . PL_N(" second", $dur->seconds);   
    }
    else {
        return;   
    }
    $str .= " ago" if $prefix;

    return $str;
}

sub time_since_datetime_detailed {
    my $self = shift;
    my $date_time = shift;
    my $prefix = shift // 1;
    
    return 'Never' unless $date_time;    
    
    my $now = DateTime->now;
    my $dur = $date_time->subtract_datetime($now);
    
    my $size = 0;
    my $str;
    
    for my $type (qw/years months weeks days hours minutes seconds/) {
        if ($dur->$type) {
            my $text = $type;
            chop $text;
            $str .= $dur->$type . PL_N(" $text", $dur->$type) . ' ';
            $size++;
        }
        last if $size >= 2;   
    }
    
    $str .= " ago" if $prefix;    
    
    return $str;        
}

1;