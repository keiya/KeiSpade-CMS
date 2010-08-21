#
# Text::Hatenaを拡張したクラス
#
package Text::HatenaEx;
use strict;
use warnings;
use base qw(Text::Hatena);
use Text::VimColor;

my @footnote;

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
super_pre	: /\n>\|(\w*)\|/o text_line(s) "\n||<" ..."\n"
));

sub h6 {
	my $class = shift;
	my $items = shift->{items};
	my $title = $class->expand($items->[1]);
	return "<h6>$title</h6>";
}

sub parse {
	my $class = shift;
	my $text = shift or return;
	$text =~ s/\r//g;
	$text = "\n" . $text unless $text =~ /^\n/;
	$text .= "\n" unless $text =~ /\n$/;
	my $node = shift || 'body';
	my $html = $class->parser->$node($text);

	# 脚注
	if(@footnote) {
		$html .= '<br>';
		for( my $i = 1; @footnote; $i++) {
			$html .= "*$i: " . shift(@footnote) .  '<br>';
		}
	}
	return $html;
}

sub inline {
	my $class = shift;
	my $items = shift->{items};
	my $item = $items->[0] or return;
	$item = Text::Hatena::AutoLink->parse($item);
	if($item =~ /\(\((.+)\)\)/) {
		my $matched = $1;
		$item = $` . "(*" . (@footnote+1) . ")" . $';
		push @footnote, $matched;
	}
	return $item;
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

sub super_pre {
	my $class = shift;
	my $items = shift->{items};
	my $filter = $1 || '';
	my $texts = $class->expand($items->[1]);

	if($items->[0] =~ /\>\|(.{1,8})\|/) {
		my $lang = $1;
		my $syntax = Text::VimColor->new(
			filetype => $lang,
		);
		$syntax->syntax_mark_string( $texts);
		return "<pre>\n" . $syntax->html() . "\n</pre>";
	}
	else {
		return "<pre>\n$texts</pre>\n";
	}
}

