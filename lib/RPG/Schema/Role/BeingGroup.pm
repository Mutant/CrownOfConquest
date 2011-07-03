package RPG::Schema::Role::BeingGroup;

use Moose::Role;

use Carp;
use Text::Autoformat;

requires qw/members number_alive group_type current_location is_online/;

sub move_to {
    my $self   = shift;
    my $sector = shift;
    
    return unless $sector;

    if ( $sector->isa('RPG::Schema::Land') ) {
        $self->land_id( $sector->id );
    }
    elsif ( $sector->isa('RPG::Schema::Dungeon_Grid') ) {
        $self->dungeon_grid_id( $sector->id );
    }
    else {
        confess "don't know how to deal with sector: $sector";
    }
}

sub compare_to_party {
    my $self = shift;
    my $party = shift || croak "Party not supplied";

    my ( $party_members, $party_af, $party_df, $party_hp, $party_dam ) = $party->factor_aggregates;
    my ( $cg_members, $cg_af, $cg_df, $cg_hp, $cg_dam ) = $self->factor_aggregates;

    my $factor_comparison =
        ( ( $party_members - $cg_members ) ) +
        ( $party_af - $cg_df ) +
        ( $party_df - $cg_af ) +
        ( ( $party_hp - $cg_hp ) / 2 ) +
        ( $party_dam - $cg_dam );

    return $factor_comparison;
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

sub has_being {
	my $self = shift;
	my $test_being = shift;
	
	return 1 if $self->id == $test_being->group_id && $self->group_type eq $test_being->group->group_type;		
}

sub display_group_type {
	my $self = shift;
	
	my $type = $self->group_type;
	$type =~ s/_/ /g;
	$type = autoformat $type, { case => 'title' };
	$type =~ s/\s*$//;
	
	return $type;
;
}

1;
