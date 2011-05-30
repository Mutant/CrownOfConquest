use strict;
use warnings;

package Test::RPG::Schema::Role::Character::Mayor;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;

sub test_lose_mayoralty_not_killed : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    my $mayor = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id, mayor_of => $town->id);
    my $garrison_char = Test::RPG::Builder::Character->build_character($self->{schema}, 
        party_id => $party->id, status => 'mayor_garrison', status_context => $town->id
    );
    
    $mayor->update({ creature_group_id => 1 });
    $garrison_char->update({ creature_group_id => 1 });
    
	my $history_rec = $self->{schema}->resultset('Party_Mayor_History')->create(
        {
            party_id => $party->id,
            town_id => $town->id,
            got_mayoralty_day => 1,
        }
    );
    
    # WHEN
    $town->mayor->lose_mayoralty(0);
    
    # THEN
    $mayor->discard_changes;
    is($mayor->mayor_of, undef, "Mayor has lost mayoralty");
    is($mayor->creature_group_id, undef, "Mayor no longer in cg");
    is($mayor->status, 'inn', "Mayor moved to the inn");
    
    $garrison_char->discard_changes;
    is($garrison_char->status, 'inn', "Garrison char moved to the inn");
    is($garrison_char->creature_group_id, undef, "Garrison char no longer in cg");
    
    $history_rec->discard_changes;
    is($history_rec->lost_mayoralty_day, $self->{stash}{today}->id, "Lost mayoarlty day is set");
}

sub test_lose_mayoralty_killed : Tests(7) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    my $mayor = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id, mayor_of => $town->id);
    my $garrison_char = Test::RPG::Builder::Character->build_character($self->{schema}, 
        party_id => $party->id, status => 'mayor_garrison', status_context => $town->id
    );
    
    $mayor->update({ creature_group_id => 1 });
    $garrison_char->update({ creature_group_id => 1 });
    
    # WHEN
    $town->mayor->lose_mayoralty(1);
    
    # THEN
    $mayor->discard_changes;
    is($mayor->mayor_of, undef, "Mayor has lost mayoralty");
    is($mayor->creature_group_id, undef, "Mayor no longer in cg");
    is($mayor->status, 'morgue', "Mayor moved to the morgue");
    is($mayor->hit_points, 0, "Mayor is dead");
    
    $garrison_char->discard_changes;
    is($garrison_char->status, 'morgue', "Garrison char moved to the morgue");
    is($garrison_char->creature_group_id, undef, "Garrison char no longer in cg");
    is($garrison_char->hit_points, 0, "Garrison char is dead");
}

1;