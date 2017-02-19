package RPG::LoadConf;

# Used for non-catalyst things that need to load the conf.

use strict;
use warnings;

use YAML;
use Data::Visitor::Callback;

sub load {
	my $package = shift;

	my $home = $ENV{RPG_HOME};

	my $config = YAML::LoadFile("$home/rpg.yml");
	my $suffix = $ENV{RPG_CONFIG_LOCAL_SUFFIX} // $ENV{CATALYST_CONFIG_LOCAL_SUFFIX} // 'local';
	if ( -f "$home/rpg_$suffix.yml" ) {
		my $local_config = YAML::LoadFile("$home/rpg_$suffix.yml");
		$config = { %$config, %$local_config };
	}
	
	$config->{home} = $home;

    my $v = Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            $package->config_substitutions( $_ );
        }
    );
    $v->visit( $config );

	return $config;
}

sub config_substitutions {
    my $c    = shift;
    my $subs = {};
    $subs->{ HOME }    ||= sub { $ENV{RPG_HOME} };
    $subs->{ ENV }    ||=
        sub {
            my ( $c, $v ) = @_;
            if (! defined($ENV{$v})) {
                die "Missing environment variable: $v\n";
                return "";
            } else {
                return $ENV{ $v };
            }
        };
    $subs->{ path_to } ||= sub { $ENV{RPG_HOME} . $_[1]; };
    $subs->{ literal } ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    for ( @_ ) {
        s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $c, $2 ? split( /,/, $2 ) : () ) }eg;
    }
}

1;