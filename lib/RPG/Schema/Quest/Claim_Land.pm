package RPG::Schema::Quest::Claim_Land;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use Games::Dice::Advanced;
use Math::Round qw(round);

sub set_quest_params {
    my $self = shift;

    my $amount_to_claim = Games::Dice::Advanced->roll('1d20') + 10;
    
    $self->define_quest_param( 'Amount To Claim', $amount_to_claim );
    $self->define_quest_param( 'Amount Claimed', 0 );
    
    $self->min_level(3);
    $self->gold_value($amount_to_claim * 8);
    $self->xp_value($amount_to_claim * 3);
    $self->days_to_complete(round $amount_to_claim / 10 + 2);
    $self->update;
}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;
    my $land_id = shift;

    return 0 unless $action eq 'claimed_land';
  
    return 0 if $self->ready_to_complete;
    
    my $quest_param = $self->param_record('Amount Claimed');
    $quest_param->current_value($quest_param->current_value+1);
    $quest_param->update;
        
    if ($self->ready_to_complete) {
        $self->status('Awaiting Reward');
        $self->update;   
    }
 
    return 1;
}

sub ready_to_complete {
    my $self = shift;
    
    return $self->param_current_value('Amount To Claim') > $self->param_current_value('Amount Claimed') ? 0 : 1;
}

sub land_left_to_claim {
    my $self = shift;
    
    return $self->param_current_value('Amount To Claim') - $self->param_current_value('Amount Claimed');
}

1;