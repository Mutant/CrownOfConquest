package RPG::NewDay::Action::Detonate;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;

sub cron_string {
    my $self = shift;

    return $self->context->config->{detonate_cron_string};
}

sub run {
    my $self = shift;

    my $c = $self->context;

    my @bombs = $c->schema->resultset('Bomb')->search(
        {
            planted => { '<=', DateTime->now->subtract( minutes => 5 ) },
            detonated => undef,
        }
    );

    my %party_msgs;
    my @damaged_upgrades;
    foreach my $bomb (@bombs) {
        push @damaged_upgrades, $bomb->detonate;
        $party_msgs{ $bomb->party_id }++;
    }

    # Leave messages for those parties who detonated bombs
    foreach my $party_id ( keys %party_msgs ) {
        my $message = ( $party_msgs{$party_id} == 1 ? 'A bomb' : $party_msgs{$party_id} . ' bombs' ) .
          ' that we planted ' . ( $party_msgs{$party_id} == 1 ? 'has' : 'have' ) . ' detonated. ' .
          scalar(@damaged_upgrades) . ' upgrades were damaged';

        $c->schema->resultset('Party_Messages')->create(
            {
                party_id    => $party_id,
                message     => $message,
                day_id      => $c->current_day->id,
                alert_party => 1,
            }
        );
    }

    # Leave messages for parties whose buildings were damaged by bombs
    my %building_damage;
    foreach my $damaged_upgrade (@damaged_upgrades) {
        my $building_id = $damaged_upgrade->{upgrade}->building_id;
        if ( !$building_damage{$building_id} ) {
            my $building = $damaged_upgrade->{upgrade}->building;
            $building_damage{$building_id}->{building} = $building;
        }

        if ( my ($existing_damage) = grep { $_->{upgrade}->id == $damaged_upgrade->{upgrade}->upgrade_id } @{ $building_damage{$building_id}->{damage} } ) {
            foreach my $key ( keys %{ $existing_damage->{damage_done} } ) {
                $existing_damage->{damage_done}{$key} += $damaged_upgrade->{damage_done}{$key} // 0;
            }
        }
        else {
            push @{ $building_damage{$building_id}->{damage} }, $damaged_upgrade;
        }
    }

    foreach my $building_id ( keys %building_damage ) {
        my $owner = $building_damage{$building_id}->{building}->owner;
        my $group_to_alert;

        for ( $building_damage{$building_id}->{building}->owner_type ) {
            if ( $_ eq 'party' ) {
                $group_to_alert = $owner;
            }
            elsif ( $_ eq 'town' ) {
                if ( $owner->mayor && !$owner->mayor->is_npc ) {
                    $group_to_alert = $owner->mayor->party;
                }
            }
            elsif ( $_ eq 'kingdom' ) {
                if ( $owner->king && !$owner->king->is_npc ) {
                    $group_to_alert = $owner->king->party;
                }
            }
        }

        next unless $group_to_alert;

        my $message = RPG::Template->process(
            $c->config,
            'newday/detonate/building_damage.html',
            {
                building_damage => $building_damage{$building_id},
            }
        );

        $c->schema->resultset('Party_Messages')->create(
            {
                party_id    => $group_to_alert->id,
                message     => $message,
                day_id      => $c->current_day->id,
                alert_party => 1,
            }
        );
    }

}

1;
