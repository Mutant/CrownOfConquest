use strict;
use warnings;

package Test::RPG::C::Player;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Player;

use RPG::C::Player;

use Data::Dumper;

sub setup_player : Tests(setup) {
    my $self = shift;
    
    $self->{mock_mime_lite} = Test::MockObject->new();
    $self->{mock_mime_lite}->fake_module('MIME::Lite',
        send => sub {},
    );
}

sub test_reactivate_form : Tests(1) {
    my $self = shift;

    # GIVEN
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{config}->{max_number_of_players} = 1;

    # WHEN
    RPG::C::Player->reactivate( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/reactivate.html', "Forward to correct template" );
}

sub test_reactivate_reform_party : Tests(4) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( {} );
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player->id, );
    $self->{config}->{max_number_of_players} = 2;

    $party1->defunct( DateTime->now() );
    $party1->update;

    isnt( $party1->defunct, undef, "Party 1 is defunct" );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, player_id => $player->id, );

    $party2->defunct( DateTime->now()->subtract( days => 1 ) );
    $party2->update;

    isnt( $party2->defunct, undef, "Party 2 is defunct" );

    $self->{params}{reform_party} = 1;
    $self->{session}{player}      = $player;

    # WHEN
    RPG::C::Player->reactivate( $self->{c} );

    # THEN
    $party1->discard_changes;
    is( $party1->defunct, undef, "Correct party marked as reformed" );

    $party2->discard_changes;
    isnt( $party2->defunct, undef, "Other party still defunct" );
}

sub test_register_game_full : Tests(1) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( {} );
    $self->{config}->{max_number_of_players} = 1;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    RPG::C::Player->register( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/full.html', "Forward to game full message" );
}

sub test_register_form : Tests(2) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( {} );
    $self->{config}->{max_number_of_players} = 2;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    RPG::C::Player->register( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/register.html', "Forward to register form" );
    is( $template_args->[0][0]{params}{message}, undef, "No message" );
}

sub test_register_missing_params : Tests(10) {
    my $self = shift;

    # GIVEN
    $self->{config}->{max_number_of_players} = 1;

    my $expected_message = "Please enter your email address, name, password and the CAPTCHA code";

    my @tests = (
        {
            params => {
                email            => '',
                player_name      => 'name',
                password1        => 'pass',
                password2        => 'pass',
                validate_captcha => 1,
            },
            desc => 'Email missing',
        },
        {
            params => {
                email            => 'foo@bar.com',
                player_name      => '',
                password1        => 'pass',
                password2        => 'pass',
                validate_captcha => 1,
            },
            desc => 'Name missing',
        },
        {
            params => {
                email            => 'foo@bar.com',
                player_name      => 'name',
                password1        => '',
                password2        => 'pass',
                validate_captcha => 1,
            },
            desc => 'Password missing',
        },
        {
            params => {
                email            => 'foo@bar.com',
                player_name      => 'name',
                password1        => 'pass',
                password2        => 'pass1',
                validate_captcha => 1,
            },
            desc => 'Passwords not matching',
        },
        {
            params => {
                email            => 'foo@bar.com',
                player_name      => 'name',
                password1        => 'pass',
                password2        => 'pass',
                validate_captcha => 0,
            },
            desc => 'Captcha invalid',
        },
    );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    my %results;
    foreach my $test (@tests) {

        $self->{params} = $test->{params};
        $self->{params}{submit} = 1;

        $self->{c}->set_always( 'validate_captcha', $self->{params}{validate_captcha} );

        RPG::C::Player->register( $self->{c} );

        $results{ $test->{desc} }{message}      = $template_args->[0][0]{params}{message};
        $results{ $test->{desc} }{player_count} = $self->{schema}->resultset('Player')->count;
    }

    # THEN
    foreach my $test (@tests) {
        is( $results{ $test->{desc} }{message}, $expected_message, $test->{desc} . " - Error message displayed" );
        is( $results{ $test->{desc} }{player_count}, 0, $test->{desc} . " - No players created" );
    }
}

sub test_register_password_too_short : Tests(3) {
    my $self = shift;

    # GIVEN
    $self->{config}->{max_number_of_players}   = 1;
    $self->{config}->{minimum_password_length} = 4;

    $self->{params} = {
        email       => 'foo@bar.com',
        player_name => 'name',
        password1   => 'pas',
        password2   => 'pas',
        submit => 1,
    };

    $self->{c}->set_always( 'validate_captcha', 1 );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    RPG::C::Player->register( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/register.html', "Forward to register form" );
    is(
        $template_args->[0][0]{params}{message},
        "Password must be at least " . $self->{config}->{minimum_password_length} . " characters",
        "Correct message"
    );
    is( $self->{schema}->resultset('Player')->count, 0, "No players created" );
}

sub test_register_duplicate_player_name : Tests(3) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( { player_name => 'name' } );
    $self->{config}->{max_number_of_players}   = 2;
    $self->{config}->{minimum_password_length} = 4;

    $self->{params} = {
        email       => 'foo@bar.com',
        player_name => 'name',
        password1   => 'pass',
        password2   => 'pass',
        submit => 1,
    };

    $self->{c}->set_always( 'validate_captcha', 1 );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    RPG::C::Player->register( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/register.html', "Forward to register form" );
    is(
        $template_args->[0][0]{params}{message},
        "A player with the name 'name' is already registered",
        "Correct message"
    );
    is( $self->{schema}->resultset('Player')->count, 1, "No more players created" );
}

sub test_register_duplicate_email : Tests(3) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( { player_name => 'name', email => 'foo@bar.com', deleted => 1 } );
    $self->{config}->{max_number_of_players}   = 2;
    $self->{config}->{minimum_password_length} = 4;

    $self->{params} = {
        email       => 'foo@bar.com',
        player_name => 'name2',
        password1   => 'pass',
        password2   => 'pass',
        submit => 1,
    };

    $self->{c}->set_always( 'validate_captcha', 1 );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_; return $template_args->[0][0]{template} };

    # WHEN
    RPG::C::Player->register( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/register.html', "Forward to register form" );
    is(
        $template_args->[0][0]{params}{message},
        'player/already_exists.html',
        "Correct message"
    );
    is( $self->{schema}->resultset('Player')->count, 1, "No more players created" );
}

sub test_register_successful : Tests(6) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( { player_name => 'name' } );
    $self->{config}->{max_number_of_players}   = 2;
    $self->{config}->{minimum_password_length} = 4;

    $self->{params} = {
        email       => 'foo@bar.com',
        player_name => 'name1',
        password1   => 'pass',
        password2   => 'pass',
        submit => 1,
    };

    $self->{c}->set_always( 'validate_captcha', 1 );
    
    $self->{mock_forward}->{'RPG::V::TT'} = sub {};    
    
    $self->{config}->{url_root} = 'url_root';

    # WHEN
    RPG::C::Player->register( $self->{c} );

    # THEN
    my ($method, $args) = $self->{mock_response}->next_call();
    is($method, 'redirect', "Redirected");
    is($args->[1], "url_root/player/verify?email=foo\@bar.com", "Correct redirect url");
    is( $self->{schema}->resultset('Player')->count, 2, "New player created" );
    
    my $new_player = $self->{schema}->resultset('Player')->find({ player_name => 'name1' });
    is($new_player->email, 'foo@bar.com', "Email set correctly");
    is($new_player->password, 'pass', "Password set correctly");
    isnt($new_player->verification_code, undef, "Verification code set");
}

sub test_login_form : Tests(2) {
    my $self = shift;

    # GIVEN
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/login.html', "Forward to correct template" );
    is( $template_args->[0][0]{params}{message}, undef, "No message");
}

sub test_login_user_doesnt_exist : Tests(2) {
    my $self = shift;

    # GIVEN
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    
    $self->{params}{email} = 'foo@bar.com';

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/login.html', "Forward to correct template" );
    is( $template_args->[0][0]{params}{message}, "Email address and/or password incorrect", "Error message set" );
}

sub test_login_password_not_given : Tests(2) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( { player_name => 'name', email => 'foo@bar.com', password => 'pass' } );
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    
    $self->{params}{email} = 'foo@bar.com';

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/login.html', "Forward to correct template" );
    is( $template_args->[0][0]{params}{message}, "Email address and/or password incorrect", "Error message set" );
}

sub test_login_password_incorrect : Tests(2) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( { player_name => 'name', email => 'foo@bar.com', password => 'pass' } );
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    
    $self->{params}{email} = 'foo@bar.com';
    $self->{params}{password} = 'pas'; 

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    is( $template_args->[0][0]{template}, 'player/login.html', "Forward to correct template" );
    is( $template_args->[0][0]{params}{message}, "Email address and/or password incorrect", "Error message set" );
}

sub test_login_not_verified : Tests(3) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( { player_name => 'name', email => 'foo@bar.com', password => 'pass', verified => 0 } );
    
    $self->{params}{email} = 'foo@bar.com';
    $self->{params}{password} = 'pass'; 

    $self->{config}->{url_root} = 'url_root';

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    my ($method, $args) = $self->{mock_response}->next_call();
    is($method, 'redirect', "Redirected");
    is($args->[1], "url_root/player/verify?email=foo\@bar.com", "Redirected to verify page");
    is($self->{session}{player}, undef, "User not stored in session");
}

sub test_login_successful : Tests(4) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( 
        { 
            player_name => 'name', 
            email => 'foo@bar.com', 
            password => 'pass', 
            verified => 1,
            warned_for_deletion => 1,
            deleted => 0, 
        } 
    );
    
    $self->{params}{email} = 'foo@bar.com';
    $self->{params}{password} = 'pass'; 

    $self->{config}->{url_root} = 'url_root';
    
    $self->{mock_forward}{post_login_checks} = sub {};

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    my ($method, $args) = $self->{mock_response}->next_call();
    is($method, 'redirect', "Redirected");
    is($args->[1], "url_root", "Redirected to main page");
    is($self->{session}{player}->id, $player->id, "User now stored in session");
    $player->discard_changes;
    is($player->warned_for_deletion, 0, "Warned for deletion flag cleared");
}

sub test_login_was_deleted : Tests(5) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( 
        { 
            player_name => 'name', 
            email => 'foo@bar.com', 
            password => 'pass', 
            verified => 1,
            warned_for_deletion => 1,
            deleted => 1, 
        } 
    );
    
    $self->{params}{email} = 'foo@bar.com';
    $self->{params}{password} = 'pass'; 

    $self->{config}->{url_root} = 'url_root';
    
    $self->{config}->{max_number_of_players} = 1;
    
    $self->{mock_forward}{post_login_checks} = sub {};

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    my ($method, $args) = $self->{mock_response}->next_call();
    is($method, 'redirect', "Redirected");
    is($args->[1], "url_root/player/reactivate", "Redirected to reactivate page");
    is($self->{session}{player}->id, $player->id, "User now stored in session");
    $player->discard_changes;
    is($player->warned_for_deletion, 0, "Warned for deletion flag cleared");
    is($player->deleted, 0, "Deleted flag cleared");
}

sub test_login_was_deleted_but_game_now_full : Tests(3) {
    my $self = shift;

    # GIVEN
    my $player = $self->{schema}->resultset('Player')->create( 
        { 
            player_name => 'name', 
            email => 'foo@bar.com', 
            password => 'pass', 
            verified => 1,
            warned_for_deletion => 1,
            deleted => 1, 
        } 
    );
    
    $self->{params}{email} = 'foo@bar.com';
    $self->{params}{password} = 'pass'; 

    $self->{config}->{url_root} = 'url_root';
    
    $self->{config}->{max_number_of_players} = 0;
    
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    
    $self->{mock_forward}{post_login_checks} = sub {};
    

    # WHEN
    RPG::C::Player->login( $self->{c} );

    # THEN
    is ($template_args->[0][0]{template}, 'player/full.html', "Forwarded to game full template");
    $player->discard_changes;
    is($player->warned_for_deletion, 1, "Warned for deletion flag still set");
    is($player->deleted, 1, "Player still deleted");
}

sub test_post_login_checks_tip_of_the_day : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $player = Test::RPG::Builder::Player->build_player($self->{schema}, display_tip_of_the_day => 1,);
	my $tip = $self->{schema}->resultset('Tip')->create(
		{
			tip => 'tip',
			title => 'title',
		}
	); 
	
	$self->{session}{player} = $player;
	
	# WHEN
	RPG::C::Player->post_login_checks( $self->{c} );
	
	# THEN
	isa_ok($self->{flash}->{tip}, "RPG::Schema::Tip", "Tip record set in flash");
	is($self->{flash}->{tip}->id, $tip->id, "Tip id matches");
}

1;
