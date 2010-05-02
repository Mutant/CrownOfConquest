package RPG::Schema::Role::BeingGroup;

use Moose::Role;

use Carp;

requires qw/members number_alive after_land_move group_type current_location/;

sub move_to {
    my $self   = shift;
    my $sector = shift;
    
    return unless $sector;

    if ( $sector->isa('RPG::Schema::Land') ) {
        $self->land_id( $sector->id );
        $self->after_land_move($sector);
    }
    elsif ( $sector->isa('RPG::Schema::Dungeon_Grid') ) {
        $self->dungeon_grid_id( $sector->id );
    }
    else {
        confess "don't know how to deal with sector: $sector";
    }
}

sub factor_aggregates {
    my $self = shift;

    my $af_aggregate;
    my $df_aggregate;
    my $hp_aggregate;
    my $dam_aggregate;
    my $members = 0;    
    
    foreach my $member ( $self->members ) {
        next if $member->is_dead;
        $members++;
        $af_aggregate  += $member->attack_factor;
        $df_aggregate  += $member->defence_factor;
        $hp_aggregate  += $member->hit_points_current;
        $dam_aggregate += $member->damage;
    }
    
    return unless $members;

    return ( $members, $af_aggregate / $members, $df_aggregate / $members, $hp_aggregate, $dam_aggregate / $members );
}

sub is {
	my $self = shift;
	my $test_group = shift || confess "Group to test not defined";
	
	return 1 if $self->id == $test_group->id && $self->group_type eq $test_group->group_type; 	
}

1;
