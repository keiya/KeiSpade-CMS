package KSpade::CGIDec;

use strict;
use warnings;

sub getline {
	my $recdata = shift;
	my %QUERY;
	$recdata =~ tr/+/ /;

	my @recdatas = split(/&/, $recdata, 10);
	
	foreach my $pair (@recdatas) {
	    my ($qname, $qvalue) = split(/=/, $pair);

		$qvalue =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2', $1)/eg;
		$qvalue =~ s/</&gt;/g unless $qname eq 'body';
		$qvalue =~ s/>/&lt;/g unless $qname eq 'body';
	    $QUERY{$qname} = $qvalue;
	}
	
	return %QUERY;
}

sub getcookies {
	my $cookies_str = shift;
	my @cookies_nd = split(/;/, $ENV{'HTTP_COOKIE'});
	my %cookies;
	foreach (@cookies_nd) {
		my ($key, $val) = split(/=/);
		$cookies{$key} = $val;
	}
	return %cookies;
}

1;
