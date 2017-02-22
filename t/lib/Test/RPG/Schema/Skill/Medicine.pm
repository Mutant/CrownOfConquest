use strict;
use warnings;

package Test::RPG::Schema::Skill::Medicine;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;

sub startup : Tests(startup) {
    my $self = shift;

    $self->mock_dice;

    $self->{skill} = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Medicine',
        }
    );
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    $self->unmock_dice;
}

sub test_execute_when_char_in_party : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 3 );
    my @chars = $party->characters;

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $self->{skill}->id,
            character_id => $chars[0]->id,
            level        => 1,
        }
    );

    $chars[1]->hit_points(2);
    $chars[1]->character_name('Victim');
    $chars[1]->update;

    $self->{rolls} = [ 1, 1 ];

    # WHEN
    $char_skill->execute('new_day');

    # THEN
    is( $party->day_logs->count, 1, "Party day logs updated" );
    my ($log) = $party->day_logs;

    like( $log->log, qr/test used his Medicine skills, and healed/, "Healer in log msg" );
    like( $log->log, qr/Victim by 3 hit points/, "Victim in log msg" );

    $chars[1]->discard_changes;
    is( $chars[1]->hit_points, 5, "Victim was healed" );
}

sub test_execute_when_char_in_garrison_with_multiple_wounded : Tests(6) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, character_count => 3, party_id => $party->id );
    my ($party_char) = $party->characters;

    $party_char->hit_points(5);
    $party_char->update;

    my @chars = $garrison->characters;

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $self->{skill}->id,
            character_id => $chars[0]->id,
            level        => 1,
        }
    );

    $chars[1]->hit_points(2);
    $chars[1]->character_name('Victim');
    $chars[1]->update;

    $chars[0]->hit_points(2);
    $chars[0]->character_name('Victim+Healer');
    $chars[0]->update;

    $self->{rolls} = [ 1, 1, 1, 2 ];

    # WHEN
    $char_skill->execute('new_day');

    # THEN
    is( $party->day_logs->count, 1, "Party day logs updated" );
    my ($log) = $party->day_logs;

    like( $log->log, qr/Victim\+Healer used his Medicine skills, and healed/, "Healer in log msg" );
    like( $log->log, qr/Victim by 4 hit points, and Victim\+Healer by 3 hit points./, "Victims in log msg" );

    $chars[1]->discard_changes;
    is( $chars[1]->hit_points, 6, "Victim was healed" );

    $chars[0]->discard_changes;
    is( $chars[0]->hit_points, 5, "Victim+Healer was healed" );

    $party_char->discard_changes;
    is( $party_char->hit_points, 5, "Party char not healed" );
}

1;
