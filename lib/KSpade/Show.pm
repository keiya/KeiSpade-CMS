package KSpade::Show;

use strict;
#use warnings;
use KSpade::Security;
use HTML::Template;

sub html {
	$main::vars{'SidebarCategoryList'} = categorylist("select tags from pages;"
		,"<dd><a href=\"./$main::vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></dd>");
	$main::vars{'SidebarPagesList'} = pageslist("select title from pages order by lastmodified_date desc, title limit $main::vars{'SidebarPagesListLimit'};"
		,"<dd><a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a></dd>");
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
	$form->{'token'} = $form{'token'};
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

sub pageslist {
	my @res = ($main::sql->fetch($_[0],0));
	my $pageslist;
	my $format = $_[1];
	foreach my $tmp (@res) {
		my $formatmp = $format;
		$formatmp =~ s/%s/$tmp/g;
		$pageslist .= $formatmp;
	}
	return $pageslist;
}

sub categorylist {
	my @res = ($main::sql->fetch($_[0],0));
	my $categorylist;
	my $format = $_[1];
	my %category;
	foreach my $tmp (@res) {
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
