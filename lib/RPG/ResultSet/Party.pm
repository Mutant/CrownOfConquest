use strict;
use warnings;
  
package RPG::ResultSet::Party;
  
use base 'DBIx::Class::ResultSet';

sub get_by_player_id {
    my $self = shift;
    my $player_id = shift;
    
    return $self->find(
        {
            player_id => $player_id,
            defunct   => undef,
        },
        {
            prefetch => [ { 'characters' => [ 'race', 'class', { 'character_effects' => 'effect' }, ] }, { 'location' => 'town' }, ],
            order_by => 'party_order',
        },
    );
}

sub average_stat {
	my $self = shift;
	my $party_id = shift;
	my $stat = shift;
	
	my ($rec) = $self->search(
		{
			'me.party_id' => $party_id,
		},
		{
			join => 'characters',
			select => { avg => 'characters.' . $stat },
			as => 'avg',
		}
	);
	
	return $rec->get_column('avg');
}
	
	
1;