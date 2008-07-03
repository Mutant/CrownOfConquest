#!/usr/bin/perl

use strict;
use warnings;

use List::Util qw(shuffle);
use DBI;

my $dbh = DBI->connect("dbi:mysql:game","root","");
$dbh->{RaiseError} = 1;

my $shops = $dbh->selectall_arrayref("select * from Shop where town_id != 0", { Slice => {} });

foreach my $shop (@$shops) {
	my ($name, $suffix) = generate_name();
	
	$dbh->do("update Shop set shop_owner_name = ?, shop_suffix = ? where shop_id = ?", {}, $name, $suffix, $shop->{shop_id});
}

sub generate_name {
	open(my $names_fh, '<', 'shop_owner_names.txt') || die "Couldn't open names file ($!)\n";
	my @names = <$names_fh>;
	close ($names_fh);
	
	chomp @names;
	my @shuffled = shuffle @names;
	
	my $prefix = $shuffled[0];

	open($names_fh, '<', 'shop_suffix.txt') || die "Couldn't open names file ($!)\n";
	@names = <$names_fh>;
	close ($names_fh);
	
	chomp @names;
	@shuffled = shuffle @names;
	
	my $suffix = $shuffled[0];
	
	return $prefix, $suffix;
}