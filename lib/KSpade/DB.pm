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
	my @arr = sort {$b->{lastmodified_date} cmp $a->{lastmodified_date}} @$all_pages;
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
	my ($page, $oldtitle) = @_;
	$self->write_pagefile($page, $oldtitle);
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
	my $page = KSpade::DB->new->get_pagelist->getpage_by_title($title);
	if ($page) {
		return $page->{pageid};
	} else {
		# TODO: もしMD5が重複したらどうすんのさ
		return md5_hex($title);
	}
}

# $pageに、ページに関する情報を補完する(pageidとか)
# TODO: 名前変える
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
	$self->write_pagefile($page);
}

sub write_pagefile {
	my $self = shift;
	my $page = shift;
	my $oldtitle = shift;

	my $fRename = 0;
	if (defined $oldtitle && $page->{title} ne $oldtitle) {
		# rename
		# 一旦タイトルだけ変更してから、本文を変更しているので非効率的
		my $plist = $self->get_pagelist;
		if (my $xml = $plist->getpage_by_title($oldtitle)) {
			$fRename = 1;
			$xml->{title} = $page->{title};
			$plist->savexml;
		}
	}

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

		my $comment = $page->{title};
		if ($fRename) {
			$comment = $comment . " (rename $oldtitle)";
		}
		commit($dir, [$fname, PAGELIST], $comment);
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
