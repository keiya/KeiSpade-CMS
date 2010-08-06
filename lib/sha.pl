package sha;

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
			$sha = &shaperl($file);
		}
	} else {
		$sha = &shaperl($file);
	}
	return $sha;
}
sub shaperl {
	require Digest::SHA::PurePerl;
	my $sha = Digest::SHA::PurePerl->new(256);
	return $sha->add($_[0])->hexdigest;
}

return 1;
