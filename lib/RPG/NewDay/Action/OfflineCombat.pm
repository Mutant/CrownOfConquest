package RPG::NewDay::Action::OfflineCombat;
use Moose;

extends 'RPG::NewDay::Base';

with 'RPG::NewDay::Role::GarrisonCombat';

use RPG::Combat::CreatureWildernessBattle;
use RPG::Combat::GarrisonCreatureBattle;

use List::Util qw(shuffle);

sub cron_string {
    my $self = shift;

    return "15 * * * *";
}

sub run {
    my $self = shift;
    my $c    = $self->context;
    
    $self->complete_battles;
    
    $self->initiate_battles;

}

sub complete_battles {
    my $self = shift;
    my $c    = $self->context;

    my @cgs = $c->schema->resultset('CreatureGroup')->search(
        {
            'in_combat_with.party_id' => { '!=', undef },
            'in_combat_with.combat_type' => 'creature_group',
            'in_combat_with.defunct'  => undef,
            'me.land_id' => { '!=', undef },
        },
        { prefetch => [ { 'creatures' => 'type' }, 'in_combat_with' ], },
    );
    $c->logger->info(scalar @cgs . " CGs with battles to complete");

    foreach my $cg (@cgs) {
        unless ( $cg->in_combat_with->is_online ) {
            $self->execute_offline_battle( $cg->in_combat_with, $cg );
        }
    }
}

sub initiate_battles {
    my $self = shift;
    my $c    = $self->context;    
    
	my $combat_count = 0;
	my $garrison_cg_combat_count = 0;
	my $garrison_party_combat_count = 0;    
    
    # Get all CGs in a sector with one or more active parties
    my $cg_rs = $c->schema->resultset('CreatureGroup')->search(
        { 
            'parties.party_id' => { '!=', undef },
            'parties.defunct' => undef,
            'parties.dungeon_grid_id' => undef, 
        },
        {
            prefetch => [ { 'creatures' => 'type' }, { 'location' => 'parties' }, ],
        },
    ); 		
     
    CG: while (my $cg = $cg_rs->next) {
        my @parties = $cg->location->parties;
        
        foreach my $party (shuffle @parties) {
        	next if $party->is_online;
        	
            my $offline_combat_count = $c->schema->resultset('Combat_Log')->get_offline_log_count( $party );
            
            next if $offline_combat_count >= $c->config->{max_offline_combat_count};

            if (Games::Dice::Advanced->roll('1d100') <= $c->config->{offline_combat_chance}) {
            	$party->initiate_combat($cg);
                $self->execute_offline_battle( $party, $cg, 1 );
                $combat_count++;                
                
                next CG;
            }   
        }
    }
    
    # Now do the garrisons vs cgs
    $cg_rs = $c->schema->resultset('CreatureGroup')->search(
        { 
            'party.defunct' => undef,
            'garrison.garrison_id' => {'!=', undef}, 
        },
        {
            prefetch => [ { 'creatures' => 'type' }, { 'location' => {'garrison' => 'party' } }, ],
        },
    );
    
    while (my $cg = $cg_rs->next) {
		if (Games::Dice::Advanced->roll('1d100') <= $c->config->{garrison_combat_chance}) {
        	$self->execute_garrison_battle( $cg->location->garrison, $cg, 1 );
            $garrison_cg_combat_count++;
		}
    }    
    
    # ... and garrisons vs parties
    my $party_rs = $c->schema->resultset('Party')->search(
    	{
    		'me.defunct' => undef,
    		'party.defunct' => undef,
            'garrison.garrison_id' => {'!=', undef},
            'me.party_id' => {'!=',\'party.party_id'},
    	},
    	{
    		prefetch => [ { 'location' => {'garrison' => 'party' } } ],
    	},
    );
    
    while (my $party = $party_rs->next) {
    	next if $party->is_online;
    	my $garrison = $party->location->garrison;
    	
    	next if $garrison->level - $party->level > $c->config->{max_party_garrison_level_difference};
    
    	next if $c->schema->resultset('Combat_Log')->get_offline_log_count( $party, undef, 1 ) > $c->config->{max_party_offline_attacks};
    	
    	if ($self->check_for_garrison_fight($party, $garrison, $garrison->party_attack_mode)) {
    		$party->initiate_combat($garrison);
        	$self->execute_garrison_battle( $garrison, $party );
            $garrison_party_combat_count++;    		    		
    	}	
    }
    
    $c->logger->info($combat_count . " battles executed");
    $c->logger->info($garrison_cg_combat_count . " garrison cg battles executed");
    $c->logger->info($garrison_party_combat_count . " garrison party battles executed");
}

sub execute_offline_battle {
    my $self  = shift;
    my $party = shift;
    my $cg    = shift;
    my $creatures_initiated = shift || 0;

    my $c      = $self->context;
    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        creature_group      => $cg,
        party               => $party,
        schema              => $c->schema,
        config              => $c->config,
        creatures_initiated => $creatures_initiated,
        log                 => $c->logger,
        creatures_can_flee  => $cg->location->orb ? 1 : 0,
    );

    while (1) {
        last if $party->is_online;

        my $result = $battle->execute_round;

        last if $result->{combat_complete};
    }
}

__PACKAGE__->meta->make_immutable;


1;
