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

	sub sha {
	   my $file = $_[0];
	   $file =~ s/|//g;
	   $file =~ s/`//g;
	   my $sha;
	   if (open(SHA1SUM, "sha256sum $file |")) {
	       my $tmp;
	       while (<SHA1SUM>) {
	           $tmp .= $_;
	       }
	       $tmp =~ s/[\n\r]+//g;
	       chomp $tmp;
	       $sha = $tmp;
	       $sha =~ m/([\w\d]+)/;
	       $sha = $1;
	       close(SHA1SUM);
	       if ($?) {
	           $sha = &shapureperl($file);
	       }
	   } else {
	       $sha = &shapureperl($file);
	   }
	   return $sha;
	}
	sub shapureperl {
	   require Digest::SHA::PurePerl;
	   my $sha = Digest::SHA::PurePerl->new(256);
	   return $sha->add($_[0])->hexdigest;
	}

1;
