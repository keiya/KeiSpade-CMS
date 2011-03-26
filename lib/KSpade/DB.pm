package KSpade::DB;

use strict;
use warnings;
use KSpade::Pagelist;
use DBI;
use Digest::Perl::MD5 'md5_hex';
use Data::Dumper;
use Carp qw(cluck);
use constant PAGELIST => 'pagelist.xml';
use constant DIR => 'dat/page';

sub new {
	my ($class) = @_;
	my $self = {};
	return bless $self, $class;
}

sub most_recently_modified_pages {
	my $self = shift;
	return ($self->recently_modified_pages_as_hash(1))[0];
}

sub recently_modified_pages_as_hash {
	my ($self, $n) = @_;
	my $all_pages = $self->get_pagelist->all_pages;
	my @arr = sort {$a->{lastmodified_date} cmp $b->{lastmodified_date}} @$all_pages;
	@arr =  (splice @arr, 0, $n) if defined $n;
	return @arr;

}

sub page_body {
	my $self = shift;
	my $title = shift;

	my $dir = DIR;
	my $fname = getfilename($title);
	if(-e "$dir/$fname") {
		my $as_scalar = `cat $dir/$fname`;
		return $as_scalar;
	}
	warn "File does not exist $fname";
	return "File does not exist $fname";
}

sub get_pagelist {
	return  KSpade::Pagelist->new(DIR.'/'.PAGELIST);
}

sub page_ashash {
	my $self = shift;
	my $title = shift;
	my $res = $self->get_pagelist->getpage_by_title($title);
	$res->{'body'} = $self->page_body($title);
	return $res;
}

sub write_page {
	my $self = shift;
	my $page = shift;
	my $page_name = shift;
	# TODO: impliment renaming a page
	$self->write_pagefile($page);
}

sub page_exist {
	my $self = shift;
	my $title = shift;
	my $dir = DIR;
	my $fname = getfilename($title);
	return -e "$dir/$fname";
}

sub delete_page {
	my $self = shift;
	my $title = shift;
	my $dir = DIR;
	my $fname = getfilename($title);
	unlink "$dir/$fname";

	my $plist = KSpade::Pagelist->new(DIR.'/'.PAGELIST);
	$plist->delpage(get_pageid_from_title($title));
	$plist->savexml;
	
	commit($dir, [$fname, PAGELIST], "delete page $title");
}

sub get_pageid_from_title {
	my $title = shift;
	# TODO: これだと、タイトルが変わるとpageidも変わってしまう。
	#       タイトルを変えたときにファイル名も変更するか、タイトルに依存しないIDをつけるかしないといけない
	#	もしMD5が重複したらどうすんのさ
	#	pagelistを使う
	return md5_hex($title);
}

# $pageに、ページに関する情報を補完する(pageidとか)
sub hokan {
	my $page = shift;

	if (!defined($page->{pageid})) {
		$page->{pageid} = get_pageid_from_title($page->{title});
	}
	if (!defined($page->{pagefilename})) {
		$page->{pagefilename} = getfilename($page->{title});
	}
	if (!defined($page->{file})) {
		$page->{file} = [];
	}
}

sub new_page {
	my $self = shift;
	my $page = shift;
	$page->{lastmodified_date} = $page->{created_date};

	#$self->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)"
	#	."values('$page->{'title'}','$page->{'created_date'}','$page->{'created_date'}','$page->{'tags'}','$page->{'autotags'}','$page->{'copyright'}','ぷよぷよフィーバー');");
	$self->write_pagefile($page);
}

sub write_pagefile {
	my $self = shift;
	my $page = shift;
	my $dir = DIR;
	my $fname = getfilename($page->{'title'});
	my $fNewPage = ! -e "$dir/$fname";
	hokan($page);
	if (open(FILE, ">$dir/$fname")) {
		print FILE $page->{'body'};
		close FILE;
		
		my $plist = KSpade::Pagelist->new(DIR.'/'.PAGELIST);
		if ($fNewPage) {
			$plist->addpage($page);
		} else {
			$plist->updatepage($page);
		}
		$plist->savexml;

		commit($dir, [$fname, PAGELIST], $page->{'title'});
	} else {
		warn $!;
	}
}

sub commit {
	my $dir = shift;
	my $files = shift;
	my $comment = shift;

	foreach (@$files) {
		`cd $dir;git add $_`;
	}

	my $flist = join(' ', @$files);
	$comment = $flist unless defined($comment);
	`cd $dir;git commit $flist -m '$comment';cd ../..`;
}

sub getfilename {
	my $title = shift;
	return get_pageid_from_title($title).".txt";
}

sub DESTROY {
	my $self = shift;
}

1;
