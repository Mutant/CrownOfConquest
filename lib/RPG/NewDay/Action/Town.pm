package RPG::NewDay::Action::Town;

use Moose;

extends 'RPG::NewDay::Base';

use Math::Round qw(round);
use List::Util qw(shuffle);
use Data::Dumper;
use Carp;

sub run {
    my $self    = shift;
    my $context = $self->context;

    my @towns = $context->schema->resultset('Town')->search( {}, { prefetch => 'location', } );

    my $ctr_avg = $context->schema->resultset('Land')->find(
        {},
        {
            'select' => { avg => 'creature_threat' },
            'as'     => 'avg_ctr',
        },
    )->get_column('avg_ctr');

    my $prosp_changes = {};

    foreach my $town (@towns) {
        $prosp_changes->{ $town->id }{town} = $town;
        $prosp_changes->{ $town->id }{original_prosp} = $town->prosperity;
        $prosp_changes->{ $town->id }{prosp_change} = $self->calculate_prosperity( $town, $ctr_avg );
    }

    $self->scale_prosperity($prosp_changes, @towns);

    $self->record_prosp_changes($prosp_changes);

    # Clear all tax paid / raids today
    $context->schema->resultset('Party_Town')->search->update( { tax_amount_paid_today => 0, raids_today => 0 } );
}

sub calculate_prosperity {
    my $self           = shift;
    my $town           = shift;
    my $global_avg_ctr = shift;

    my $context = $self->context;

    my $party_town_rec = $context->schema->resultset('Party_Town')->find(
        { town_id => $town->id, },
        {
            select => [                  { sum => 'tax_amount_paid_today' }, { sum => 'raids_today' } ],
            as     => [ 'tax_collected', 'raids_today' ],
        }
    );

    my $ctr_avg = $town->location->get_surrounding_ctr_average( $context->config->{prosperity_calc_ctr_range} );

    my $ctr_diff = $global_avg_ctr - $ctr_avg;
    $ctr_diff = 0 if $ctr_diff < 0;

    my $prosp_change =
        ( ( $party_town_rec->get_column('tax_collected') || 0 ) / 10 ) +
        ( $ctr_diff / 20 ) -
        ( ( $party_town_rec->get_column('raids_today') || 0 ) / 4 );

    $prosp_change = $context->config->{max_prosp_change} if $prosp_change > $context->config->{max_prosp_change};

    if ( $prosp_change == 0 ) {
        if ( Games::Dice::Advanced->roll('1d3') == 1 ) {
            $prosp_change = -1;
        }
    }

    $prosp_change = round $prosp_change;

    $context->logger->info( "Changing town " . $town->id . " prosperity by $prosp_change" );

    $town->prosperity( $town->prosperity + $prosp_change );
    $town->prosperity(1) if $town->prosperity < 1;
    $town->prosperity(100) if $town->prosperity > 100;
    $town->update;

    return $prosp_change;
}

sub scale_prosperity {
    my $self  = shift;
    my $prosp_changes = shift;
    my @towns = @_;

    # Needs to add up to 100
    # TODO: config this
    my %target_prosp = (
        90 => 4,
        80 => 6,
        70 => 8,
        60 => 8,
        50 => 10,
        40 => 14,
        30 => 14,
        20 => 13,
        10 => 13,
        0  => 10,
    );

    my %actual_prosp = $self->_get_prosperty_percentages(@towns);

    $self->context->logger->info( "Current Prosperity percentages: " . Dumper \%actual_prosp );

    my %changes_needed = $self->_calculate_changes_needed( \%target_prosp, \%actual_prosp, scalar @towns );

    $self->context->logger->info( "Changes required: " . Dumper \%changes_needed );

    $self->_change_prosperity_as_needed( $prosp_changes, \%actual_prosp, \@towns, %changes_needed );

}

sub _calculate_changes_needed {
    my $self         = shift;
    my $target_prosp = shift;
    my $actual_prosp = shift;
    my $town_count   = shift;

    my %changes_needed;
    foreach my $category ( keys %$target_prosp ) {
        $actual_prosp->{$category} ||= 0;
        if ( $target_prosp->{$category} < $actual_prosp->{$category} - 2 ) {
            my $diff = $actual_prosp->{$category} - $target_prosp->{$category};
            $changes_needed{$category} = - round( $town_count * ( $diff / 100 ) );
        }
        if ( $target_prosp->{$category} > $actual_prosp->{$category} + 2 ) {
            my $diff = $target_prosp->{$category} - $actual_prosp->{$category};
            $changes_needed{$category} = round( $town_count * ( $diff / 100 ) );
        }
    }

    return %changes_needed;
}

sub _select_town_from_category {
    my $self     = shift;
    my $category = shift;
    my @towns    = @_;

    my $outer_bound = $category + 9;
    $outer_bound = 100 if $outer_bound == 99;

    foreach my $town ( shuffle @towns ) {
        next unless $town->prosperity >= $category && $town->prosperity <= $outer_bound;
        return $town;
    }

    confess "Can't find town for category $category";
}

sub _change_prosperity_as_needed {
    my $self           = shift;
    my $prosp_changes  = shift;
    my $actual_prosp   = shift;
    my $towns          = shift;
    my %changes_needed = @_;

    foreach my $category ( sort keys %changes_needed ) {
        no warnings 'uninitialized';

        # Add more towns to category
        if ( $changes_needed{$category} > 0 ) {
            for ( 1 .. $changes_needed{$category} ) {
                my $from_category;
                if ( $changes_needed{ $category - 10 } < 0 ) {
                    $from_category = $category - 10;
                    $changes_needed{$from_category}++;
                }
                elsif ( $changes_needed{ $category + 10 } < 0 ) {
                    $from_category = $category + 10;
                    $changes_needed{$from_category}++;
                }
                else {
                    if ( defined $actual_prosp->{ $category - 10 } ) {
                        $from_category = $category - 10;
                    }
                    else {
                        $from_category = $category + 10;
                    }
                }

                my $town_to_change = $self->_select_town_from_category( $from_category, @$towns );
                my $modifier = $category > $from_category ? 3 : -3;

                $self->context->logger->debug( "Modifying town with prosp: " . $town_to_change->prosperity . " by $modifier" );

                $prosp_changes->{$town_to_change->id}{prosp_change}+=$modifier;

                $town_to_change->prosperity( $town_to_change->prosperity + $modifier );
                $town_to_change->update;

                $changes_needed{$category}--;
            }
        }

        # Remove towns from category
        if ( $changes_needed{$category} < 0 ) {
            for ( 1 .. abs $changes_needed{$category} ) {
                my $to_category;
                if ( $changes_needed{ $category - 10 } > 0 ) {
                    $to_category = $category - 10;
                    $changes_needed{$to_category}--;
                }
                elsif ( $changes_needed{ $category + 10 } > 0 ) {
                    $to_category = $category + 10;
                    $changes_needed{$to_category}--;
                }
                else {
                    if ( defined $actual_prosp->{ $category + 10 } ) {
                        $to_category = $category + 10;
                    }
                    else {
                        $to_category = $category + 10;
                    }
                }

                my $town_to_change = $self->_select_town_from_category( $category, @$towns );
                my $modifier = $category > $to_category ? -3 : 3;

                $self->context->logger->debug( "Modifying town with prosp: " . $town_to_change->prosperity . " by $modifier" );

                $prosp_changes->{$town_to_change->id}{prosp_change}+=$modifier;

                $town_to_change->prosperity( $town_to_change->prosperity + $modifier );
                $town_to_change->update;

                $changes_needed{$category}++;
            }
        }
    }
}

sub _get_prosperty_percentages {
    my $self  = shift;
    my @towns = @_;

    my %actual_prosp;
    foreach my $town (@towns) {
        my $category;
        if ( length $town->prosperity == 1 ) {
            $category = 0;
        }
        elsif ( $town->prosperity >= 100 ) {
            $category = 90;
        }
        else {
            $town->prosperity =~ /^(\d)\d$/;
            $category = $1 . '0';
        }

        $actual_prosp{$category}++;
    }

    map { $actual_prosp{$_} = round( $actual_prosp{$_} / scalar(@towns) * 100 ) } keys %actual_prosp;

    return %actual_prosp;
}

sub record_prosp_changes {
    my $self = shift;
    my $prosp_changes = shift;
    
    my $c = $self->context;
    
    foreach my $town_id (keys %$prosp_changes) {
        if ($prosp_changes->{$town_id}{prosp_change} != 0) {
            my $message = RPG::Template->process(
                $c->config,
                'newday/town/prosp_change.html',
                {
                    %{ $prosp_changes->{$town_id} }
                },
            );            
            
            $c->schema->resultset('Town_History')->create(
                {
                    message => $message,
                    town_id => $town_id,
                    day_id => $c->current_day->id,
                }
            );   
        }   
    }   
}

1;
