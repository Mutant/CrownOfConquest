package RPG::Schema::Election;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Election');

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

1;