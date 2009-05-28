package RPG::NewDay::Action::Town;

use Moose;

extends 'RPG::NewDay::Base';

use Math::Round qw(round);

sub run {
    my $self    = shift;
    my $context = $self->context;

    my @towns = $context->schema->resultset('Town')->search( {}, { prefetch => 'location', } );

    foreach my $town (@towns) {
        $self->calculate_prosperity($town);
    }

    # Clear all tax paid
    $context->schema->resultset('Party_Town')->search->update( { tax_amount_paid_today => 0 } );
}

sub calculate_prosperity {
    my $self = shift;
    my $town = shift;

    my $context = $self->context;

    my $tax_collected = $context->schema->resultset('Party_Town')->find(
        { town_id => $town->id, },
        {
            select => { sum => 'tax_amount_paid_today' },
            as     => 'tax_collected',
        }
    )->get_column('tax_collected') || 0;

    my $ctr_avg = $town->location->get_surrounding_ctr_average( $context->config->{prosperity_calc_ctr_range} );

    my $activity_factor = $context->yesterday->turns_used / 1000;
    $activity_factor = 1.5 if $activity_factor > 1.5;

    my $prosp_change = ( ( $tax_collected / 10 ) - ( $ctr_avg / 20 ) ) * $activity_factor; 
    
    return if $prosp_change == 0;

    $prosp_change = $context->config->{max_prosp_change}  if $prosp_change > $context->config->{max_prosp_change};
    $prosp_change = -$context->config->{max_prosp_change} if $prosp_change < -$context->config->{max_prosp_change};

    $context->logger->info( "Changing town " . $town->id . " prosperity by $prosp_change" );

    $town->prosperity( $town->prosperity + round $prosp_change);
    $town->update;
}

1;
