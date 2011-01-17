#package security;

sub exorcism {
	my $tmp = $_[0];
	$tmp =~ s/'/''/g;
	$tmp =~ s/\\/&#92;/g;
	#$tmp =~ s/</&lt;/g;
	#$tmp =~ s/>/&gt;/g;
	return $tmp;
}

sub html {
	my $tmp = $_[0];
	$tmp =~ s/</&lt;/g;
	$tmp =~ s/>/&gt;/g;
	return $tmp;
}

sub ahtml {
	my $tmp = $_[0];
	$tmp =~ s/&/&amp;/g;
	$tmp =~ s/</&lt;/g;
	return $tmp;
}

sub textalize {
	my $tmp = $_[0];
	#$tmp =~ s/[^\w\d_\-\(\) ぁ-ヶ亜-黑]+//g;
	$tmp =~ s/[\n\t~`!@#\$%^&\*=\+\{\}\\;:'"<>\?\/]+//g;
	return $tmp;
}

sub noscript {
	my $tmp = $_[0];
	$tmp =~ s/<(.+?)>/&lt;$1&gt;/g;
	return $tmp;
}

sub htmlexor {
	my $tmp = $_[0];
	return &textalize(&exorcism($tmp));
}

1;
