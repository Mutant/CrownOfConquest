use strict;
use warnings;

package RPG::ResultSet::Party;

use base 'DBIx::Class::ResultSet';

use DateTime;

sub get_by_player_id {
    my $self      = shift;
    my $player_id = shift;
    
    my %null_fields = map { 'characters.' . $_ => undef } RPG::Schema::Character->in_party_columns;

    return $self->find(
        {
            player_id => $player_id,
            defunct   => undef,
			%null_fields,
        },
        {
            prefetch => [
                { 'characters' => [ 'race', 'class',     { 'character_effects' => 'effect' }, ] },
                { 'location'   => 'town' },
            ],
            order_by => 'party_order',
        },
    );
}

sub search_by_last_action {
    my $self = shift;
    my $params = shift;
    my $attrs = shift;
        
    my $comparison = delete $params->{online} ? '>=' : '<';
        
    return $self->search(
        {
            last_action => {$comparison,  DateTime->now()->subtract( minutes => RPG::Schema->config->{online_threshold} )},
            %$params,
        },
        $attrs,
    );   
}

1;
