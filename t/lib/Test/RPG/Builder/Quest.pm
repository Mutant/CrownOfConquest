use strict;
use warnings;

package Test::RPG::Builder::Quest;

use Carp;

sub build_quest {
    my $self = shift;
    my $schema = shift;
    my %params = @_;
    
    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => $params{quest_type} } );
    
    confess "Can't find quest type: " . $params{quest_type} unless $quest_type;
    
    my %create_params;
    if ($params{town_id}) {
        $create_params{town_id} = $params{town_id};
    }
    elsif ($params{kingdom_id}) {
        $create_params{kingdom_id} = $params{kingdom_id};
    }         
    
    my $quest = $schema->resultset('Quest')->create(
        {
            quest_type_id => $quest_type->id,
            status        => $params{status} || 'Not Started',
            party_id      => $params{party_id},
            day_offered   => $params{day_offered} || undef,
            %create_params,
            params        => $params{params},
        }
    );
    
    return $quest;
}

1;