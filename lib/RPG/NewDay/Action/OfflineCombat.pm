package RPG::NewDay::Action::OfflineCombat;
use Moose;

extends 'RPG::NewDay::Base';

with 'RPG::NewDay::Role::GarrisonCombat';

use RPG::Combat::CreatureWildernessBattle;
use RPG::Combat::GarrisonCreatureBattle;

use List::Util qw(shuffle);

sub cron_string {
    my $self = shift;

    return "*/15 * * * *";
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
            'in_combat_with.defunct'  => undef,
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
    
    # Get all CGs in a sector with one or more active parties or garrisons
    my @cgs = $c->schema->resultset('CreatureGroup')->search(
        {},
        {
            prefetch => [ { 'creatures' => 'type' }, { 'location' => 'parties' }, ],
        },
    );
      
	$c->logger->info(scalar @cgs . " CGs in sectors with active parties");
	
	my $combat_count = 0;
	my $garrison_combat_count = 0;
      
    CG: foreach my $cg (@cgs) {
        my @parties = $cg->location->parties;
        
        foreach my $party (shuffle @parties) {
            next if ! $party || $party->is_online || $party->in_combat || $party->dungeon_grid_id || $party->defunct;
            
            my $offline_combat_count = $c->schema->resultset('Combat_Log')->get_offline_log_count( $party );
            
            next if $offline_combat_count >= $c->config->{max_offline_combat_count};

            if (Games::Dice::Advanced->roll('1d100') <= $c->config->{offline_combat_chance}) {
                $self->execute_offline_battle( $party, $cg, 1 );
                $combat_count++;                
                
                next CG;
            }   
        }
        
        if (my $garrison = $cg->location->garrison) {
       		next if $garrison->in_combat;
      		
       		if (Games::Dice::Advanced->roll('1d100') <= $c->config->{garrison_combat_chance}) {
       			$self->execute_garrison_battle($garrison, $cg, 1);	
       			$garrison_combat_count++;
       		}
       			
        }
    }
    
    
    $c->logger->info($combat_count . " battles executed");
    $c->logger->info($garrison_combat_count . " garrison battles executed");
}

1;
