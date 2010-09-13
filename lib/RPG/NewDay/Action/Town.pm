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
        $prosp_changes->{ $town->id }{town}           = $town;
        $prosp_changes->{ $town->id }{original_prosp} = $town->prosperity;
        $prosp_changes->{ $town->id }{prosp_change}   = $self->calculate_prosperity( $town, $ctr_avg );
    }

    $self->scale_prosperity( $prosp_changes, @towns );

    $self->record_prosp_changes($prosp_changes);

    # Update prestige ratings
    $self->update_prestige;

    $self->set_discount(@towns);
}

sub calculate_prosperity {
    my $self           = shift;
    my $town           = shift;
    my $global_avg_ctr = shift;

    my $context = $self->context;

    my $party_town_rec = $context->schema->resultset('Party_Town')->find(
        { town_id => $town->id, },
        {
            select => [ { sum => 'tax_amount_paid_today' }, { sum => 'raids_today' } ],
            as     => [ 'tax_collected', 'raids_today' ],
        }
    );

    my $ctr_avg = $town->location->get_surrounding_ctr_average( $context->config->{prosperity_calc_ctr_range} );

    my $ctr_diff = $global_avg_ctr - $ctr_avg;
    $ctr_diff = 0 if $ctr_diff < 0;
    
    my $tax_collected = 0;
    my $raids_today = 0;
    
    if ($party_town_rec) {
    	$tax_collected = $party_town_rec->get_column('tax_collected');
    	$raids_today = $party_town_rec->get_column('raids_today');
    }
    
    my $approval_change = round (($town->mayor_rating // 0) / 20);

    my $prosp_change =
        ( ( $tax_collected || 0 ) / 10 ) +
        ( $ctr_diff / 20 ) -
        ( ( $raids_today || 0 ) / 4 ) +
        $approval_change;

    $prosp_change = $context->config->{max_prosp_change}  if $prosp_change > $context->config->{max_prosp_change};
    $prosp_change = -$context->config->{max_prosp_change} if $prosp_change < -$context->config->{max_prosp_change};

    if ( $prosp_change == 0 ) {
        if ( Games::Dice::Advanced->roll('1d3') == 1 ) {
            $prosp_change = -1;
        }
    }

    $prosp_change = round $prosp_change;

    $context->logger->info( "Changing town " . $town->id . " prosperity by $prosp_change (currently : " . $town->prosperity . ')'. 
    	" [Tax: $tax_collected, Ctr Avg: $ctr_avg, Ctr Diff: $ctr_diff, Raid: $raids_today, Approval chg: $approval_change]");

    $town->adjust_prosperity( $prosp_change );
    $town->update;

    return $prosp_change;
}

sub scale_prosperity {
    my $self          = shift;
    my $prosp_changes = shift;
    my @towns         = @_;

    # Needs to add up to 100
    # TODO: config this
    my %target_prosp = (
        90 => 7,
        80 => 9,
        70 => 11,
        60 => 11,
        50 => 10,
        40 => 11,
        30 => 11,
        20 => 10,
        10 => 10,
        0  => 10,
    );

	my $logged;

	for my $category (reverse sort keys %target_prosp) {
    	my %actual_prosp = $self->_get_prosperity_percentages(@towns);

    	$self->context->logger->info( "Current Prosperity percentages: " . Dumper \%actual_prosp )
    		unless $logged;

    	my %changes_needed = $self->_calculate_changes_needed( \%target_prosp, \%actual_prosp, scalar @towns );

	    $self->context->logger->info( "Changes required: " . Dumper \%changes_needed )
	    	unless $logged;	    
	    
	    $logged = 1;
    	
    	$self->_make_scaling_changes( $category, $changes_needed{$category}, $prosp_changes, @towns );	    	
	}
	
	my %actual_prosp = $self->_get_prosperity_percentages(@towns);
	$self->context->logger->info( "Percentages post scaling: " . Dumper \%actual_prosp )
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
            $changes_needed{$category} = -round( $town_count * ( $diff / 100 ) );
        }
        if ( $target_prosp->{$category} > $actual_prosp->{$category} + 2 ) {
            my $diff = $target_prosp->{$category} - $actual_prosp->{$category};
            $changes_needed{$category} = round( $town_count * ( $diff / 100 ) );
        }
    }

    return %changes_needed;
}

sub _make_scaling_changes {
	my $self = shift;
	my $category = shift;
	my $changes_needed = shift // 0;
	my $prosp_changes = shift;
	my @towns = @_;

	# Scaling involves adding or removing from lower category. Can't do that if category is 0
	return if $category == 0;
	
	# Check there are actually some changes to make
	return if $changes_needed == 0;

	my $lower_category = $category - 10;
	
	# If changes needed is less than 0, we push towns from this category into the next one
	#  Otherwise we pull towns up from the lower category
	my $category_to_move_from = $changes_needed < 0 ? $category : $lower_category;
	
	# Get all the towns from this category, sorted by the adjustments they've made today (least adjusted first)
	my $category_upper_bound = $category_to_move_from == 90 ? 100 : $category_to_move_from+9; 
	
	my @towns_to_move = grep { $_->prosperity >= $category_to_move_from && $_->prosperity <= $category_upper_bound } @towns;

	@towns_to_move = sort { 
			abs $prosp_changes->{$a->id}->{prosp_change} <=> abs $prosp_changes->{$b->id}->{prosp_change} ||
			($changes_needed < 0 ?
				$a->prosperity <=> $b->prosperity :
				$b->prosperity <=> $a->prosperity)
	} @towns_to_move;
	
	# See if there are more changes needed than towns in this category
	# TODO: if we're moving up from the category below, should we get more from the category below that?
	$changes_needed = scalar @towns_to_move if $changes_needed > scalar @towns_to_move;

	for (1..abs $changes_needed) {
		my $town = shift @towns_to_move;
		my $prosperity = $town->prosperity;
		
		# Random component ensure we don't get a huge cluster of towns around the edge of the category
		my $random = Games::Dice::Advanced->roll('1d3');

		my $new_prosperity;
		
		if ($changes_needed < 0) {
			$new_prosperity = $category - $random;		
		}
		else {
			$new_prosperity = $category + $random - 1;
		}
		
		my $change = $new_prosperity - $prosperity;

		$self->context->logger->debug("Scaling town " . $town->id . " from $prosperity to $new_prosperity");
		
		$prosp_changes->{$town->id}{prosp_change} += $change;
		
		$town->prosperity($new_prosperity);
		$town->update;
	} 
}

sub _get_prosperity_percentages {
    my $self  = shift;
    my @towns = @_;

    my %actual_prosp;
    foreach my $town (@towns) {
        my $category;
        if ( $town->prosperity <= 9 ) {
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
    my $self          = shift;
    my $prosp_changes = shift;

    my $c = $self->context;

    foreach my $town_id ( keys %$prosp_changes ) {
        if ( $prosp_changes->{$town_id}{prosp_change} != 0 && $prosp_changes->{$town_id}{original_prosp} != $prosp_changes->{$town_id}{town}->prosperity ) {
            my $message = RPG::Template->process( $c->config, 'newday/town/prosp_change.html', { %{ $prosp_changes->{$town_id} } }, );

            $c->schema->resultset('Town_History')->create(
                {
                    message => $message,
                    town_id => $town_id,
                    day_id  => $c->current_day->id,
                }
            );
        }
    }
}

sub update_prestige {
    my $self = shift;

    my $c = $self->context;

    my $party_town_rs = $c->schema->resultset('Party_Town')->search(
        {
            prestige        => { '!=', 0 },
            'party.defunct' => undef,
        },
        { join => 'party', },
    );

    while ( my $party_town = $party_town_rs->next ) {
        if ( Games::Dice::Advanced->roll('1d3') == 1 ) {
            if ( $party_town->prestige > 0 ) {
                $party_town->prestige( $party_town->prestige - 1 );
            }
            else {
                $party_town->prestige( $party_town->prestige + 1 );
            }
            $party_town->update;
        }
    }
}

sub set_discount {
    my $self  = shift;
    my @towns = @_;

    my $c = $self->context;

    my @discount_types = @{ $c->config->{discount_types} };

    my $discount_range = $c->config->{max_discount_value} - $c->config->{min_discount_value};
    my $discount_steps = $discount_range / 5 + 1;

    foreach my $town (@towns) {
        my $chance_for_discount = $town->prosperity / 2;
        $chance_for_discount = 20 if $chance_for_discount < 20;

        my $discount_roll = Games::Dice::Advanced->roll('1d100');
        
        my @available_discount_types = @discount_types;
        if ($town->blacksmith_age == 0) {
            # Get rid of blacksmith type if there's no blacksmith
            @available_discount_types = grep { $_ ne 'blacksmith' } @available_discount_types;
        }

        if ( $chance_for_discount <= $discount_roll ) {
            my $discount_type      = ( shuffle @available_discount_types )[0];
            my $discount_value     = ( Games::Dice::Advanced->roll( '1d' . $discount_steps ) - 1 ) * 5 + $c->config->{min_discount_value};
            my $discount_threshold = Games::Dice::Advanced->roll('1d5') * 5 + 70;

            $town->discount_type($discount_type);
            $town->discount_value($discount_value);
            $town->discount_threshold($discount_threshold);
        }
        else {
            $town->discount_type(undef);
        }

        $town->update;
    }
}

__PACKAGE__->meta->make_immutable;


1;
