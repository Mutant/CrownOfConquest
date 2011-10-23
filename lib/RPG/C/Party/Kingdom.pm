package RPG::C::Party::Kingdom;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub auto : Private {
    my ( $self, $c ) = @_;
    
    $c->stash->{kingdom} //= $c->stash->{party}->kingdom;
    
    return 1;
}

sub main : Local {
	my ( $self, $c ) = @_;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/kingdom/main.html',
				params => {
					party => $c->stash->{party},
					kingdom => $c->stash->{kingdom},
				},
			}
		]
	);
}

sub allegiance : Local {
	my ( $self, $c ) = @_;
	
	my $kingdom = $c->stash->{kingdom};
	
	my @kingdoms = $c->model('DBIC::Kingdom')->search(
	   {
	       active => 1,
	       'me.kingdom_id' => {'!=', $c->stash->{party}->kingdom_id},
	   },
	   {
	       order_by => 'name',
	   }
    );
    
    @kingdoms = grep { 
        my $party_kingdom = $_->find_related('party_kingdoms',
            {
                'party_id' => $c->stash->{party}->id,
            }
        );
        $party_kingdom && $party_kingdom->banished_for > 0 ? 0 : 1;
    } @kingdoms;
    
    my @banned = $c->model('DBIC::Party_Kingdom')->search(
        {
            party_id => $c->stash->{party}->id,
            banished_for => {'>=', 0},
        },
        {
            prefetch => 'kingdom',
        }
    );
    
	my $mayor_count = $c->stash->{party}->search_related(
		'characters',
		{
			mayor_of => {'!=', undef},
		},
	)->count;	    
	
	my $can_declare_kingdom = $c->stash->{party}->level >= $c->config->{minimum_kingdom_level} 
	   && $mayor_count >= $c->config->{town_count_for_kingdom_declaration};
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/kingdom/allegiance.html',
                params   => {
                    kingdom => $kingdom,
                    kingdoms => \@kingdoms,
                    allegiance_change_frequency => $c->config->{party_allegiance_change_frequency},
                    party => $c->stash->{party},
                    mayor_count => $mayor_count,
                    town_count_for_kingdom_declaration => $c->config->{town_count_for_kingdom_declaration},
                    minimum_kingdom_level => $c->config->{minimum_kingdom_level},
                    can_declare_kingdom => $can_declare_kingdom,
                    banned => \@banned,
                    in_combat => $c->stash->{party}->in_combat,
                },
            }
        ]
    );		    
}

sub parties : Local {
	my ( $self, $c ) = @_;
	
	my @parties = $c->stash->{kingdom}->search_related(
	   'parties',
	   {},
	   {
	       order_by => 'name',
	       join      => 'characters',
	       '+select' => [
	           {count => 'characters.character_id'},
	       ],
	       '+as' => ['character_count'],
	       group_by  => 'me.party_id',
	   }
    );
    
    @parties = sort { $b->level <=> $a->level } @parties;
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/parties.html',
				params => {
				    parties => \@parties,
				    kingdom => $c->stash->{kingdom},
				    banish_min => $c->config->{min_banish_days},
				    banish_max => $c->config->{max_banish_days},
				    is_king => $c->stash->{is_king},
				},
			}
		]
	);	 	
}

sub records : Local {
    my ($self, $c) = @_;
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/records.html',
				params => {
				    kingdom => $c->stash->{kingdom},
				},
			}
		]
	);       
}

sub towns : Local {
    my ($self, $c) = @_;
    
	my @towns = $c->model('DBIC::Town')->search(
	   {
	       'location.kingdom_id' => $c->stash->{kingdom}->id,
	   },
	   {
	       'join' => 'location',
	       'order_by' => 'town_name',
	   }
    );   
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/kingdom/towns.html',
				params => {
				    towns => \@towns,
				    kingdom => $c->stash->{kingdom},
				},
			}
		]
	);        
}

sub messages : Local {
	my ($self, $c) = @_;
	
	my @types = 'public_message';
	push @types, 'message' if $c->stash->{is_king};
	
	my @messages = $c->stash->{kingdom}->search_related(
	   'messages',
	   {
	       'day.day_number' => {'>=', $c->stash->{today}->day_number - 14},
	       'type' => \@types,
	   },
	   {
	       prefetch => 'day',
	       order_by => ['day.day_id desc', 'message_id desc'],
	   }
	);
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/messages.html',
				params => {
				    messages => \@messages,
				},
			}
		]
	);		  
}

1;