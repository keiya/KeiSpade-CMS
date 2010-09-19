package Security;

sub new {
	my $class = shift;

	my $self = {};
	return bless $self, $class;
}

sub exorcism {
	my ($self, $tmp) = @_;
	$tmp =~ s/'/''/g;
	$tmp =~ s/\\/&#92;/g;
	#$tmp =~ s/</&lt;/g;
	#$tmp =~ s/>/&gt;/g;
	return $tmp;
}

sub html {
	my ($self, $tmp) = @_;
	$tmp =~ s/</&lt;/g;
	$tmp =~ s/>/&gt;/g;
	return $tmp;
}

sub htmlexor {
	my ($self, $tmp) = @_;
	my $html = $self->html($tmp);
	return $self->exorcism($html);
}

sub textalize {
	my ($self, $tmp) = @_;
	#$tmp =~ s/[^\w\d_\-\(\) ぁ-ヶ亜-黑]+//g;
        $tmp =~ s/[\n\t~`!@#\$%^&\*=\+\{\}\\;:'"<>\?\/]+//g;
	return $tmp;
}

sub noscript {
	my ($self, $tmp) = @_;
	$tmp =~ s/<.+>//g;
	return $tmp;
}

1;
