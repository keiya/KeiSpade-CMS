#
# Text::Hatenaを拡張したクラス
#
package Text::HatenaEx;
use strict;
use warnings;
use utf8;
use base qw(Text::Hatena);

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
	my $class = shift;
	my $items = shift->{items};
	my $title = $class->expand($items->[1]);
	return "<h6>$title</h6>";
}

sub video {
	my $mvar = shift;
	my $url = $mvar->[1];
	return sprintf( '<video src="%s" controls="controls">%s</video>', $url, $url);
}

sub audio {
	my $mvar = shift;
	my $url = $mvar->[1];
	return sprintf( '<audio src="%s" controls="controls">%s</audio>', $url, $url);
}

# AutoLinkを拡張する
Text::Hatena::AutoLink->syntax({
	'\[(.*):video\]' => \&Text::HatenaEx::video,
	'\[(.*):audio\]' => \&Text::HatenaEx::audio,
});

