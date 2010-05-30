

#
# Yoayaku.in (CGI request string decode script) Perl SubScript
# Version 1.0.0 alpha
# CGIリクエスト文字列をデコードし、クエリ名をキーとしたハッシュを返します
#
# usage 
# %hash = &cgidec::getline
#
# Written by Keiya CHINEN <keiya_21@yahoo.co.jp>
# 
# CGIDEC --> Yoyaku.in Custom <--


package cgidec;

sub getline {
	my %QUERY;
	my $recdata = $_[0];
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

sub getfile {
#	my $files = $_[]

}



sub getform {


}

return 1;

