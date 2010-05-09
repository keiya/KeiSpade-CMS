package security;

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

sub textalize {
	my $tmp = $_[0];
	#$tmp =~ s/[^\w\d_\-\(\) ぁ-ヶ亜-黑]+//g;
        $tmp =~ s/[\n\t~`!@#\$%^&\*=\+\{\}\\;:'"<>\?\/]+//g;
	return $tmp;
}

sub noscript {
	my $tmp = $_[0];
	$tmp =~ s/<\/?script>/--cannot use script tag--/g;
	$tmp =~ s/<\/?iframe>/--cannot use iframe tag--/g;
	return $tmp;
}

1;
