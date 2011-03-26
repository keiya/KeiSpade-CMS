package KSpade::SQL;
sub get_category_list {
	my ($self) = @_;
	my $ret = [];

	foreach (@{$self->get_pagelist->all_pages}) {
		push @$ret, $_->{tags};
	}
	return $ret;
}

package KSpade::Show;

use strict;
use warnings;
use Data::Dumper;
use KSpade::Security;
use HTML::Template;

sub html {
	$main::vars{'SidebarCategoryList'} = categorylist(
		KSpade::SQL->new->get_category_list(),
		"<dd><a href=\"./$main::vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></dd>");
	my @list;
	foreach (KSpade::SQL->new->recently_modified_pages_as_hash($main::vars{'SidebarPagesListLimit'})) {
		push @list, [$_->{title}, $_->{title}];
	}
	$main::vars{'SidebarPagesList'} = pageslist(
		\@list, "<dd><a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a></dd>");
	my $html;
	$html = template($_[0], $_[1]);
	print "${main::vars{'HttpStatus'}}\n${main::vars{'HttpContype'}}\n\n";
	print $html;
}

sub xml {
	my $xml;
	$xml = template($_[0], $_[1]);
	print "${main::vars{'HttpStatus'}}\n${main::vars{'HttpContype'}}\n\n";
	print $xml;
}

# ページ編集・作成用共通サブルーチン
sub formelements {
	my $form = $_[0];
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = KSpade::CGIDec::getline($postdata);

	$form->{'title'} = KSpade::Security::textalize(KSpade::Security::exorcism($form{'title'}));
	$form->{'modified_date'} = time();
	$form->{'created_date'} = time();
	$form->{'tags'} = '';
	$form->{'autotags'} = '';
	$form->{'confer'} = '';
	$form->{'copyright'} = '';
	$form->{'body'} = KSpade::Security::exorcism($form{'body'});
	$form->{'bodyhash'} = KSpade::Security::exorcism($form{'bodyhash'});

	$form->{'title'} =~ s/ +$// if defined $form->{'title'};

	my $tagstr = $form->{'title'};
	if (defined $tagstr) {
		$tagstr =~ s/^\[(.+)\](.+)/$1/g;
		if (defined $2) {
			my @tagstrs= split(/\]\[/, $tagstr);
			foreach my $tag (@tagstrs) {
				$tag =~ s/[\[\]]+//g;
				$form->{'tags'} .= $tag.'|';
			}
		}
	}
}

#TODO (closure(to select), closure(to sort), format) みたいなインターフェースがベスト
sub pageslist {
	my ($arr, $format) = @_;
	my $pageslist = '';
	foreach (@$arr) {
		if (defined $_ && ref($_) eq 'ARRAY') {
			my $tmp = sprintf $format, @$_;
			$pageslist .= $tmp;
		}
	}
	return $pageslist;
}

#TODO (closure(to select), closure(to sort), format) みたいなインターフェースがベスト
sub categorylist {
	my ($arr, $format) = @_;
	my $categorylist;
	my %category;
	foreach my $tmp (@$arr) {
		my @tags = split(/\|/, $tmp);
		foreach my $tag (@tags) {
			my $formatmp = $format;
			$formatmp =~ s/%s/$tag/g;
			$categorylist .= $formatmp if not exists $category{$tag};
			$category{$tag} = 1;
		}
	}
	return $categorylist;
}

sub template {
	my $template = HTML::Template->new(filename => $_[0],
	                                   die_on_bad_params => 0,
	                                   cache => 1,
	                                   no_includes => 1,
	                                  );
	$template->param(%{$_[1]});
	return $template->output;
}

1;
