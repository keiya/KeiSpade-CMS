#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

# include modules
use File::Basename qw(basename);

use lib './lib';
use KSpade;

my $time_start = (times)[0];

# script file name
my $myname = basename($0, '');

# generate absolute uri
my $absuri = '';
if ($ENV{'SERVER_PORT'} == 443) {
	$absuri .= 'https://'
} else {
	$absuri .= 'http://'
}

if ($ENV{'SERVER_NAME'} ne '') {
	$absuri .= $ENV{'SERVER_NAME'};
} else {
	$absuri .= $ENV{'HTTP_HOST'};
}

$absuri .= $ENV{'REQUEST_URI'};

my $abspath = $absuri;
$abspath =~ s/$myname.+$//;

# constants, default values
our %vars = ( 'SiteName'=>'KeiSpade','SiteDescription'=>'The Multimedia Wiki','ScriptName'=>$myname,
              'ScriptAbsolutePath'=>$abspath, 'SidebarPagesListLimit'=>'10','ContentLanguage'=>'ja',
              'DefaultAuthor'=>'anonymous' );
%vars = (%vars, KSpade::Conf::load('./dat/kspade.conf'));
$vars{'Version'}  = '0.4.1';

# http header + html meta header
$vars{'HttpStatus'} = 'Status: 200 OK';
$vars{'HttpContype'}= "Content-Type: text/html; charset=UTF-8";
$vars{'HtmlHead'} = '<meta charset=utf-8 /><link href="./css/kspade.css" rel="stylesheet" type="text/css" media="screen,print">';
$vars{'HtmlHead'} .= "<link rel=\"contents\" href=\"./$vars{'ScriptName'}?cmd=search\">";
$vars{'HtmlHead'} .= "<link rel=\"start\" href=\"./$vars{'ScriptName'}?page=TopPage\">";
$vars{'HtmlHead'} .= "<link rel=\"index\" href=\"./$vars{'ScriptName'}?cmd=category\">";

# process cgi args
our %query = KSpade::CGIDec::getline($ENV{'QUERY_STRING'});

KSpade::Misc::setpagename($query{'page'});

our $db = KSpade::DB->new;

if (defined $query{'adon'}) {
	my $addon_name = KSpade::Security::file($query{'adon'});
	require './addons/'.$addon_name.'.cgi';
	my $addon_pkg_name = 'KSpade::Addon::'.$addon_name;
	no strict 'refs';
	&{$addon_pkg_name.'::new'};
	&{$addon_pkg_name.'::'.$query{'acmd'}};
	&{$addon_pkg_name.'::DESTROY'};
} elsif (defined $query{'cmd'}) {
	no strict 'refs';
	&{$query{'cmd'}}; # if cmd=post, call 'post'
} elsif ((not defined $query{'cmd'}) and (defined $main::vars{'PageName'})) {
	&page;
}

# print page
sub page { 
	my $hash_ofpage = $main::db->page_ashash($main::vars{'PageName'});
	if (defined $hash_ofpage->{'title'}) {
		my $tags = $hash_ofpage->{'tags'};
		chop $tags;

		my $modified = KSpade::DateTime::relative($hash_ofpage->{'lastmodified_date'});
		my $created = KSpade::DateTime::relative($hash_ofpage->{'created_date'});

		$main::vars{'HtmlHead'} .= '<title>'.$hash_ofpage->{'title'}.'@'.$main::vars{'SiteName'}.'</title>';

		$main::vars{'HtmlBody'} .= "<h2>$hash_ofpage->{'title'}</h2>";
		$main::vars{'HtmlBody'} .=
		    Text::HatenaEx->parse(KSpade::Security::noscript($hash_ofpage->{'body'}));

		if (defined $hash_ofpage->{file}) {
			my $confer = '';
			foreach (@{$hash_ofpage->{file}}) {
				$confer .= "<a href=\"dat/page/files/$_->{filename}\">$_->{originalname}</a> [<a href=\"./$main::vars{'ScriptName'}?&page=$main::vars{'PageName'}&amp;filename=$_->{filename}&amp;adon=upl&amp;acmd=delupload\" rel=\"nofollow\">X</a>] ";
				$confer =~ s/[\[\]]+//g;
			}
			my $s = (@{$hash_ofpage->{file}} > 1) ? 's' : '';
			$main::vars{'HtmlBody'} .= '</section><section><h2>Attached File'.$s.'</h2>'.$confer.'</section>';
		}
		$main::vars{'MetaInfo'} = "Last-modified: $modified, Created: $created, Tags: $hash_ofpage->{'tags'}, AutoTags: $hash_ofpage->{'autotags'}<br />$hash_ofpage->{'copyright'}<br />";
	} else {
		$main::vars{'HtmlHead'} .= '<title>Not Found'.'@'.$main::vars{'SiteName'}.'</title>';
		$main::vars{'HtmlBody'} .= "KeiSpade does not have a page with this exact name. <a href=\"$main::vars{'ScriptName'}?page=$main::vars{'PageName'}&cmd=new\">Write the $main::vars{'PageName'}</a>.";
		$main::vars{'HttpStatus'} = 'Status: 404 Not Found';
	}
	my $time_stop = (times)[0];
	$main::vars{'HtmlConvertTime'}= $time_stop - $time_start;
	KSpade::Show::html('html/body.html',\%main::vars);
}

sub atom {
	my $pupdated = $db->most_recently_modified_pages->{lastmodified_date};
	$pupdated = KSpade::DateTime::spridtarg($pupdated);
	chomp $pupdated;
	$main::vars{'AtomUpdated'} = $pupdated;
	$main::vars{'AtomEntries'} .= "<id>${abspath}$main::vars{'ScriptName'}?cmd=atom</id>";
	foreach ($db->recently_modified_pages_as_hash(5)) {
		my $etitle = KSpade::Misc::urlenc($_->{title});
		my $id     = "${abspath}$main::vars{'ScriptName'}?page=$etitle";
		my $link   = "./$main::vars{'ScriptName'}?page=$etitle";
		my $body   = $db->page_body($_->{title});
		$body = "No text" if $body eq '';
		my $pbody = KSpade::Security::ahtml(Text::HatenaEx->parse(KSpade::Security::html(KSpade::Security::noscript($body))));
		my @tag = split(/\|/,$_->{tags});
		my $ptag = '';
		foreach my $tmp (@tag) {
			$ptag .= "<category term=\"$tmp\" />";
		}
		my $update  = KSpade::DateTime::spridtarg($_->{lastmodified_date});
		my $publish = KSpade::DateTime::spridtarg($_->{created_date});
		$main::vars{'AtomEntries'} .= "<entry><title>$_->{title}</title><id>$id</id>".
			"<author><name>$_->{author}</name></author>".
			"<link rel=\"alternate\" href=\"$link\" />".
			"<updated>$update</updated><published>$publish</published>$ptag".
			"<content type=\"html\">$pbody</content></entry>\n";
	}
	KSpade::Show::xml('html/atom.xml',\%main::vars);
}

# print edit page form
sub edit {
	my @res = ($db->page_body($main::vars{'PageName'}));
	#$res[0] =~ s/<br \/>/\n/g;
	$main::vars{'DBody'} = $res[0];
	require 'sha.pl';
	$main::vars{'BodyHash'} = &sha::pureperl($res[0]);
	#$main::vars{'Token'} = rand)
	$main::vars{'HtmlHead'} .= '<meta http-equiv="Expires" content="0">';
	$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}.' &gt; Edit@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/editbody.html',\%vars);
	delete $main::vars{'DBody'};
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
} 

# submit edited text
sub post {
	my $pagename = $main::vars{'PageName'};

	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		my %page;
		KSpade::Show::formelements(\%page);
		chomp %page;
		require 'sha.pl';
		my $res = $db->page_ashash($main::vars{'PageName'});
		my $hashparent = &sha::pureperl($res->{'body'});
		if (($page{'bodyhash'} eq $hashparent) or ($page{'bodyhash'} =~ /Conflict/)) {
			$page{'title'} = 'undefined'.rand(16384) if $page{'title'} eq '';
			$db->write_page( \%page, $main::vars{'PageName'});
			KSpade::Misc::setpagename($page{'title'});
			$main::vars{'HttpStatus'} = 'Status: 303 See Other';
			$main::vars{'HttpStatus'} .= "\nLocation: $main::vars{'ScriptAbsolutePath'}$main::vars{'ScriptName'}?page=$main::vars{'PageName'}";
			KSpade::Show::html('html/frmwrk.html',\%main::vars);
		} else {
			# conflicted
			require Text::Diff;
			my $diff = Text::Diff::diff(\$res->{'title'},\$page{'body'});
			$diff =~ s/\n/<br \/>/g;
			$main::vars{'Diff'} = $diff;
			$main::vars{'Body'} = $res->{'title'};
			$main::vars{'DBody'} = $page{'body'};
			$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}.' &gt; Error@'.$main::vars{'SiteName'}.'</title>';
			$main::vars{'HtmlBody'} .= KSpade::Show::template('html/conflict.html',\%vars);
			delete $main::vars{'Diff'};
			delete $main::vars{'Body'};
		}
	}
} 

# submit edited text
sub preview {
	my $pagename = $main::vars{'PageName'};

	my %page;
	KSpade::Show::formelements(\%page);
	chomp(%page);
	if ($pagename eq $page{'title'}) {
		KSpade::Misc::setpagename($page{'title'});
		&page;
	}

	my $parsed .= Text::HatenaEx->parse(KSpade::Security::noscript($page{'body'}));
	$main::vars{'HtmlBody'} .= $parsed;
	#KSpade::Show::html('html/frmwrk.html',\%main::vars);
	KSpade::Show::html('html/preview.html',\%main::vars);
} 

# print new page form
sub new {
	$main::vars{'HtmlHead'} .= '<meta http-equiv="Pragma" content="no-cache">';
	$main::vars{'HtmlHead'} .= '<title> New@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/newbody.html',\%vars);
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

# submit new page
sub newpost {
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		my %page;
		KSpade::Show::formelements(\%page);
		chomp(%page);
		if($db->page_exist($page{'title'})) {
			$page{'title'} = $page{'title'}.rand(16384);
		} elsif($page{'title'} eq '') {
			$page{'title'} = 'undefined'.rand(16384);
		}
		$main::vars{'PageName'} = $page{'title'};
		$db->new_page( \%page);

		KSpade::Misc::setpagename($main::vars{'PageName'});
		$main::vars{'HttpStatus'} = 'Status: 303 See Other';
		$main::vars{'HttpStatus'} .= "\nLocation: ${abspath}$main::vars{'ScriptName'}?page=$main::vars{'PageName'}";
	}
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

# print delete confirm
sub del {
	$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}.' &gt; Delete@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/delete.html',\%vars);
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

# delete page
sub delpage {
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		$db->delete_page($main::vars{'PageName'});
	}
	$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}.' &gt; Deleted@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/deleted.html',\%vars);
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

# search subroutine
sub search {
	my $query = KSpade::Security::htmlexor($query{'query'});
	$query =~ s/\s/AND/g if defined $query;
	$main::vars{'Query'} = $query{'query'};
	if (defined $query{'query'}) {
		# normal search
		my $list = [];
		my @pagelist = sort {$a->{lastmodified_date} cmp $b->{lastmodified_date}} @{$db->get_pagelist->all_pages};
		foreach (@pagelist) {
			push @$list, [$_->{title}, $_->{title}] if /$query/ =~ $db->page_body;
		}
		KSpade::Show::pageslist( 
			$list,
			"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");

		$main::vars{'HtmlHead'} .= '<title>Search &gt; Body@'.$main::vars{'SiteName'}.'</title>';
		$main::vars{'HtmlBody'} .= KSpade::Show::template('html/search.html',\%vars);
		delete $main::vars{'PagesList'};

	}
	# print all pages
	else {
		my @list;
		foreach (@{$db->get_pagelist->all_pages}) {
			push @list, [$_->{title}, $_->{title}];
		}
		$main::vars{'PagesList'} = KSpade::Show::pageslist(
			\@list,
			"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
		$main::vars{'HtmlHead'} .= '<title>PagesList@'.$main::vars{'SiteName'}.'</title>';
		$main::vars{'HtmlBody'} .= KSpade::Show::template('html/list.html',\%vars);
		delete $main::vars{'PagesList'};
	}
	delete $main::vars{'Query'};
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
} 

# print categories
sub category {
	my $query = KSpade::Security::htmlexor($query{'query'});
	$query =~ s/\s/AND/g;
	$main::vars{'Query'} = $query{'query'};
	if ($main::vars{'Query'} eq '') {
		# Index of categories
		$main::vars{'CategoryTitle'} = "Index of Categories";
		$main::vars{'CategoryList'} = '<ul>';

		$main::vars{'CategoryList'} .= KSpade::Show::categorylist(
			$db->get_category_list(sub {[$_[0], $_[0]]}),
			"<li><a href=\"./$main::vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></li>");
		$main::vars{'CategoryList'} .= '</ul>';
	} else {
		# TODO: selectを使う
		my @list;
		foreach (@{$db->get_pagelist->all_pages}) {
			push @list, [$_->{title}, $_->{title}] if ($_->{tags} =~ /$query/);
		}
		$main::vars{'CategoryTitle'} = "Pages related to '$main::vars{'Query'}'";
		$main::vars{'CategoryList'} = KSpade::Show::categorylist(\@list,
			"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
	}
	$main::vars{'HtmlHead'} .= '<title>Search &gt; Category@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/category.html',\%vars);
	delete $main::vars{'CategoryTitle'};
	delete $main::vars{'CategoryList'};
	delete $main::vars{'Query'};
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
} 

# initialize top page
sub init_toppage {
	my $modified_date = time();
	my $created_date = $modified_date;
	my $body = KSpade::Show::template('html/tutorial.txt',\%vars);

	$db->new_page({'title' => 'TopPage', 'lastmodified_date' => $modified_date,
			'created_date' => $created_date, 'tags' => 'Help', 'autotags' => 'Help',
			'copyright' => 'Copyleft', 'body' => $body});
}

