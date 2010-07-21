use strict;
use warnings;

package RPG::ResultSet::Character;

use base 'DBIx::Class::ResultSet';

use Carp;
use List::Util qw(shuffle);
use File::Slurp;
use Games::Dice::Advanced;

sub generate_character {
    my $self        = shift;
    my $race        = shift || croak "Race not supplied";
    my $class       = shift || croak "Class not supplied";
    my $level       = shift || croak "Level not supplied";
    my $xp          = shift // croak "Xp not supplied";
    my $roll_points = shift // 1;
    
    if ($level > 1 && $roll_points == 0) {
        croak "Can only turn off rolling points for level 1 characters";   
    }

    my %stats = (
        'strength'     => $race->base_str,
        'agility'      => $race->base_agl,
        'intelligence' => $race->base_int,
        'divinity'     => $race->base_div,
        'constitution' => $race->base_con,
    );

    my $stat_pool = RPG::Schema->config->{stats_pool};
    my $stat_max  = RPG::Schema->config->{stat_max};

    # Initial allocation of stat points
    %stats = $self->_allocate_stat_points( $stat_pool, $stat_max, $class->primary_stat, \%stats );
    
    # Yes, we're quite sexist
    my $gender = Games::Dice::Advanced->roll('1d3') > 1 ? 'male' : 'female';

    my $character = $self->create(
        {
            character_name => _generate_name($gender),
            class_id       => $class->id,
            race_id        => $race->id,
            level          => $level,
            xp             => $xp,
            party_order    => undef,
            gender         => $gender,
            %stats,
        }
    );

    # Roll for first level
    $character->roll_all if $roll_points;

    # Roll stats for all further levels above 1
    for ( 2 .. $level ) {
        $character->roll_all;

        %stats = $self->_allocate_stat_points( RPG::Schema->config->{stat_points_per_level}, undef, $class->primary_stat, \%stats );

        for my $stat ( keys %stats ) {
            $character->set_column( $stat, $stats{$stat} );
        }

        $character->update;
    }

    if ($roll_points) {
        $character->hit_points( $character->max_hit_points );
        $character->update;
    }

    return $character;
}

sub _allocate_stat_points {
    my $self         = shift;
    my $stat_pool    = shift;
    my $stat_max     = shift;
    my $primary_stat = shift;
    my $stats        = shift;

    my @stats = keys %$stats;
    push @stats, $primary_stat;    # Primary stat goes in multiple times to make it more likely to get added

    # Allocate 1 point to a random stat until the pool is used
    while ( $stat_pool > 0 ) {
        my $stat = ( shuffle @stats )[0];

        # Make sure we dont exceed the stat max (if one was supplied)
        # TODO: possible infinite loop
        next if defined $stat_max && $stats->{$stat} == $stat_max;

        $stats->{$stat}++;

        $stat_pool--;
    }

    return %$stats;
}

my %names;

sub _generate_name {
    my $gender = shift;
    
    my $file_prefix = $gender eq 'male' ? '' : 'female_';
    
    unless ($names{$gender}) {
        @{$names{$gender}} = read_file( RPG::Schema->config->{data_file_path} . "/${file_prefix}character_names.txt" );
    }
    
    my @names = @{$names{$gender}};

    chomp @names;
    @names = shuffle @names;

    return $names[0];
}

1;
