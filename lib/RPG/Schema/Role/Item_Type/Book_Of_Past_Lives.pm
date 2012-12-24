package RPG::Schema::Role::Item_Type::Book_Of_Past_Lives;

use strict;
use warnings;

use Moose::Role;
use Try::Tiny;

with 'RPG::Schema::Role::Item_Type::Usable';

sub display_name {
    my $self = shift;
        
    return "Book of Past Lives";
}

sub label {
    my $self = shift;
    
    return "Read Book of Past Lives";   
}

sub is_usable {
    my $self = shift;
    my $combat = shift // 0;
    my $character = shift;
    
    return 0 if $combat;
        
    return 0 unless $character;
            
    return 1;
}

sub use {
    my $self = shift;
    my $target = shift;
    
    return unless $self->is_usable(0);
    
    my $character = $self->belongs_to_character;
    
    return unless $character;
    
    $character->character_skills->delete;
    
    $character->skill_points($character->level - 1);
    $character->update;
    
    return RPG::Combat::SpellActionResult->new(
        {
            type => 'book_of_past_lives',
            spell_name => 'read',
            defender => $character,
            attacker => $character,
        }
    );        
}

sub requires_confirmation { 1 }

sub confirmation_message {
    my $self = shift;
        
    my $character = $self->belongs_to_character;    
    
    return "Are you sure you want " . $character->name . " to read the Book? This will reset all " . $character->pronoun('posessive-objective') .
        " skills."; 
}

sub target {'self'}

1;