#!/usr/bin/perl
use lib './lib';

#
# Text::Hatenaを拡張したクラス
#
package Text::HatenaEx;
use utf8;
use base Text::Hatena;
__PACKAGE__->syntax(q(
	block	: h6
	| h5
	| h4
	| blockquote
	| dl
	| list
	| super_pre
	| pre
	| table
	| cdata
	| p
	h6	: "\n****" inline(s)
));

sub h6 {
	print ">>>>> h6\n";
	my $class = shift;
	my $items = shift->{items};
	my $title = $class->expand($items->[1]);

	print "<<<<< h6\n";
	return "<H6>$title</H6>";
}


