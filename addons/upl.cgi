#!/usr/bin/perl

# KeiSpade Uploader
# KeiSpade Developping Team
# upl.pl 0.4.1

package KSpade::DB;
use strict;
use warnings;
use Data::Dumper;

sub page_update_modifiedtime {
	my ($self, $page) = @_;
	$page->{lastmodified_date} = time();
}

sub add_attached_file {
	my ($self, $title, $originalname, $filename) = @_;
	my $plist = get_pagelist;
	my $page = $plist->getpage_by_title($title);

	if (defined $page) {
		$page->{file} = [] if (!defined $page->{file} or ref($page->{file}) ne 'ARRAY');
		push @{$page->{file}}, { filename => $filename, originalname => $originalname };
		$self->page_update_modifiedtime( $page);
		$plist->savexml;
		commit(DIR, ['files/'.$filename, PAGELIST], "upload file $originalname ($filename) in $title");
	}
}

sub del_attached_file {
	my ($self, $title, $fname) = @_;
	my $plist = get_pagelist;
	my $page = $plist->getpage_by_title($title);

	# the num of pages which reffers the file
	my $ref_count = @{$plist->search(
		sub { if (ref($_[0]->{file}) eq 'ARRAY') { foreach (@{$_[0]->{file}}) { return 1 if $_->{filename} eq $_[1]}} 0},
		$fname)};
	unlink $fname if ($ref_count == 1);

	if (defined $page && defined $page->{file}) {
		for (my $i = 0; $i < @{$page->{file}}; $i++) {
			if($page->{file}[$i]->{filename} eq $fname) {
				splice @{$page->{file}}, $i, 1;
				last;
			}
		}
		$self->page_update_modifiedtime( $page);
		$plist->savexml;
		commit(DIR, ['files/'.$fname, PAGELIST], "delete file $fname in $title");
	}
}

package KSpade::Addon::upl;
use strict;
use warnings;
use lib '../lib';
use Carp;
use KSpade;
use KSpade::DB;
use Data::Dumper;

sub new {
	$main::vars{'Addons::upl::UploaderName'} = 'addons/upl/upload.cgi';
}

# print update form
sub upload {
	# print upload form
	$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}. ' &gt; Upload@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/upload.html',\%main::vars);

	KSpade::Show::html('html/frmwrk.html',\%main::vars);
} 

# print delete confirm
sub delupload {
	my $filename = KSpade::Security::htmlexor($main::query{'filename'});
	$main::vars{'DeleteFileName'} = $filename;
	my @pages = @{get_page_list_which_has_file($filename)};
	$main::vars{'PagesList'} = KSpade::Show::pageslist(
		$main::db->get_pagelist->select_(
			sub {
				my $oname = get_original_name($_[0], $filename);
				if (defined $oname) {
					return [$_[0]->{title}, $_[0]->{title}];
				}
				return undef;
			}),
		"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
	$main::vars{'HtmlHead'} .= '<title>'.$filename. ' &gt; Delete Uploaded Files@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/delupload.html',\%main::vars);
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

sub get_original_name {
	my ($page, $fname) = @_;
	return undef unless &has_file($page);
	foreach (@{$page->{file}}) {
		if ($_->{filename} eq $fname && defined $_->{originalname}) {
			return $_->{originalname};
		}
	}
	return undef;
}

sub has_file {
	if (defined $_[0]->{file}) {
		foreach (@{$_[0]->{file}}) {
			return 1 if $_->{filename} eq $main::query{filename};
		}
	}
	0;
}

sub get_page_list_which_has_file {
	my $fname = $_[0];
	return $main::db->get_pagelist->search( \&has_file);
}

sub delfile {
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		my $filename = KSpade::Security::htmlexor($main::query{'filename'});
		#my @pages = $main::db->fetch("select title from pages where confer like '%$filename%';",0);
		my $pages = &get_page_list_which_has_file($filename);
		KSpade::DB->new->del_attached_file($main::vars{PageName}, $filename);
		KSpade::Misc::setpagename($main::vars{'PageName'});
		$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}.' &gt; File was Deleted@'.$main::vars{'SiteName'}.'</title>';
		$main::vars{'HtmlBody'} .= KSpade::Show::template('html/deletedupl.html',\%main::vars);
	}
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

sub addfile {
	# submit file
	my %page;
	KSpade::Show::formelements(\%page);
	chomp(%page);

	$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}. ' &gt; UploadProcess@'.$main::vars{'SiteName'}.'</title>';
	my $filename = KSpade::Security::htmlexor($main::query{'filename'});
	my $original = KSpade::Security::htmlexor($main::query{'orig'});
	#my @res = ($main::db->fetch("select confer from pages where title='$main::vars{'PageName'}';"));
	#my $files = $res[0];
	my $page = KSpade::DB->new->get_pagelist->getpage_by_title($main::vars{PageName});
	if (defined $page->{file} && join(' ', @{$page->{file}}) =~ /$filename/) {
	} else {
		my $tmp  = KSpade::DateTime::spridate('%04d %2d %2d %2d:%02d:%02d');
		#$files .= "[$filename/$original($tmp)]";
		#$main::db->do("update pages set lastmodified_date='$page{'modified_date'}', confer='$files' where title='$main::vars{'PageName'}';");
		KSpade::DB->new->add_attached_file($main::vars{'PageName'}, $original, $filename);
	}

	print "Content-Type: text/html; charset=UTF-8\n\n";
	#KSpade::Show::html('../html/frmwrk.html',\%main::vars);
}

sub DESTROY {
	my $self = shift;
}

1;
