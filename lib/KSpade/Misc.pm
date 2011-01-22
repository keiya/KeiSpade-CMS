package KSpade::Misc;

use strict;
use warnings;
use KSpade::Security;

sub urlenc {
	my $string = $_[0];
	$string =~ s/([^\w ])/'%'.unpack('H2', $1)/eg;
	$string =~ tr/ /+/;
	$string = uc($string);
	return $string
}

sub setpagename {
	$main::vars{'PageName'} = KSpade::Security::exorcism($_[0]);
	if (not defined $main::vars{'PageName'} or not $main::vars{'PageName'} =~ /.+/) {
		$main::vars{'PageName'} = 'TopPage'
	}
	$main::vars{'NoSpacePageName'} = $main::vars{'PageName'};
	$main::vars{'NoSpacePageName'} =~ tr/ /+/;
}


1;
