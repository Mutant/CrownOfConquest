package RPG::Schema::Election;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Election');

__PACKAGE__->resultset_class('RPG::ResultSet::Election');

__PACKAGE__->add_columns(qw/election_id town_id scheduled_day status/);

__PACKAGE__->set_primary_key('election_id');

__PACKAGE__->belongs_to(
    'town',
    'RPG::Schema::Town',
    'town_id',
);

__PACKAGE__->has_many(
    'candidates',
    'RPG::Schema::Election_Candidate',
    'election_id',
);

sub cancel {
    my $self = shift;
    
	$self->status("Cancelled");
	$self->update;
	
	# Give back any campaign spends
	my @candidates = $self->search_related(
	   'candidates',
	   {
	       campaign_spend => {'>=', 0},
	   }
    );
    
    my $today = $self->result_source->schema->resultset('Day')->find_today;
    
    foreach my $candidate (@candidates) {
        my $character = $candidate->character;
        if (! $character->is_npc) {
            my $party = $character->party;
            $party->increase_gold($candidate->campaign_spend);
            $party->update;
            
            $party->add_to_messages(
                {
                    alert_party => 1,
                    day_id => $today->id,
                    message => 'The election in ' . $self->town->town_name . ' has been cancelled. Your campaign spend of ' . 
                        $candidate->campaign_spend . ' gold has been returned to the party',
                }
            );         
        }   
    }
}

1;