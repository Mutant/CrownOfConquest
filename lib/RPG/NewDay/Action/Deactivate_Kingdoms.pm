package RPG::NewDay::Action::Deactivate_Kingdoms;

# Mark any kingdoms with 0 towns as inactive.
#  All land becomes neutral, King removed, and party become free citizens

use Moose;

extends 'RPG::NewDay::Base';

sub cron_string {
    my $self = shift;

    return $self->context->config->{deactivate_kingdoms_cron_string};
}

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my @kingdoms = $c->schema->resultset('Kingdom')->search(
        {
            active => 1,
        }
    );    
    
    foreach my $kingdom (@kingdoms) {
        $self->check_for_inactive($kingdom);
    }
}

sub check_for_inactive {
    my $self = shift;
    my $kingdom = shift;
    
    my $c = $self->context;    
    
    my $town_count = $c->schema->resultset('Town')->search(
        {
            'location.kingdom_id' => $kingdom->id
        },
        {
            'join' => 'location',
        }
    )->count;
    
    return 0 if $town_count > 0;
  
    $kingdom->active(0);
    $kingdom->fall_day_id($c->current_day->day_id);
    $kingdom->update;
    
    $kingdom->search_related('sectors')->update( { kingdom_id => undef } );
    $kingdom->town_loyalty->delete;
    
    my $king = $kingdom->king;
    
    # Make sure we include defunct parties
    my @parties = $c->schema->resultset('Party')->search(
        {
            kingdom_id => $kingdom->id,
        }
    );

    foreach my $party (@parties) {
        $party->change_allegiance(undef);
        $party->last_allegiance_change(undef);
        $party->cancel_kingdom_quests($kingdom);
        
        if ($king->is_npc || $party->id != $king->party_id) {
            $party->add_to_messages(
                {
                    day_id => $c->current_day->id,
                    alert_party => 1,
                    message => "The Kingdom of " . $kingdom->name . " has fallen. We are now free citizens",
                }
            );
        }
        
        $party->update;
    }

    $king->status(undef);
    $king->status_context(undef);
    $king->update;
    
    if (! $king->is_npc) {
        my $party = $king->party;
        $party->add_to_messages(
            {
                day_id => $c->current_day->id,
                alert_party => 1,
                message => "Our mighty Kingdom of " . $kingdom->name . " has fallen, as we no longer own any towns. A sad day indeed.",
            },
        );
    }
    
    return 1;
}

1;
