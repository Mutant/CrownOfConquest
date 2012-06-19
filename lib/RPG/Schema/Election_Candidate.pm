package RPG::Schema::Election_Candidate;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Election_Candidate');

__PACKAGE__->add_columns(qw/election_id character_id campaign_spend/);

__PACKAGE__->set_primary_key(qw/election_id character_id/);


__PACKAGE__->numeric_columns(
	campaign_spend => {
		min_value => 0,	
	}
);

__PACKAGE__->belongs_to(
    'election',
    'RPG::Schema::Election',
    'election_id',
);

__PACKAGE__->belongs_to(
    'character',
    'RPG::Schema::Character',
    'character_id',
);

sub max_spend {
    my $self = shift;
    
    my $character = $self->character;
    
    return if $character->is_npc;
    
    my $party_level = $character->party->level;
    my $prosp = $self->election->town->prosperity;
    
    return (($party_level*5) + ($prosp/4)) * 1000;
}

1;