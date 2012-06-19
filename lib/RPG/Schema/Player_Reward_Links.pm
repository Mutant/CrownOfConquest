package RPG::Schema::Player_Reward_Links;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

use RPG::DateTime;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Player_Reward_Links');

__PACKAGE__->add_columns(qw/player_id link_id vote_key/);

__PACKAGE__->add_columns(
    last_vote_date => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key(qw/link_id player_id/);

__PACKAGE__->belongs_to( 'link', 'RPG::Schema::Reward_Links', 'link_id' );

sub time_since_last_vote {
    my $self = shift;
    
    return RPG::DateTime->time_since_datetime_detailed($self->last_vote_date);
}

1;