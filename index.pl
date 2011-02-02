#!/usr/bin/perl

use strict;
use warnings;

# include modules
use File::Basename qw(basename);

use lib './lib';
use KSpade;

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
$vars{'Version'}  = '0.4.0';

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

# connect to DB
my $database = './dat/kspade.db';
my $data_source = "dbi:SQLite:dbname=$database";
our $sql = KSpade::SQL->new($data_source);

# database initialize (create the table)
if ($sql->tableexists == 0) {
	$sql->create_table;
	my $modified_date = time();
	my $created_date = $modified_date;
	my $body = KSpade::Show::template('html/tutorial.txt',\%vars);
	$sql->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
		values ('TopPage','$modified_date','$created_date','Help','Help','Copyleft','$body');");
	$vars{'HtmlHead'} .= '<link href="./css/light.css" rel="stylesheet" type="text/css">';
	$vars{'HtmlHead'} .= '<title>Miracle! Table was created!</title>';
	$vars{'HtmlBody'} .= '<p>Table was created. Please reload.</p>';
}




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
	&{$query{'cmd'}};
} elsif ((not defined $query{'cmd'}) and (defined $main::vars{'PageName'})) {
	&page;
}

# print page
sub page { 
	my $hash_ref = ($main::sql->fetch_ashash("select * from pages where title='".$main::vars{'PageName'}."';"));
	my $hash_ofpage = $hash_ref->{$main::vars{'PageName'}};
	if (defined $hash_ofpage->{'title'}) {
		my $tags = $hash_ofpage->{'tags'};
		chop $tags;

		my $modified = KSpade::DateTime::relative($hash_ofpage->{'lastmodified_date'});
		my $created = KSpade::DateTime::relative($hash_ofpage->{'created_date'});

		$main::vars{'HtmlHead'} .= '<title>'.$hash_ofpage->{'title'}.'@'.$main::vars{'SiteName'}.'</title>';

		require 'Text/HatenaEx.pm';
		$main::vars{'HtmlBody'} .= "<h2>$hash_ofpage->{'title'}</h2>";
		$main::vars{'HtmlBody'} .=
		    Text::HatenaEx->parse(KSpade::Security::noscript($hash_ofpage->{'body'}));

		my $confer;
		if (defined $hash_ofpage->{'confer'}) {
			my @filedatas= split(/\]\[/, $hash_ofpage->{'confer'});
			foreach my $filedata (@filedatas) {
				my @elements = split(/\//, $filedata);
				$confer .= "<a href=\"files/$elements[0]\">$elements[1]</a> [<a href=\"./$main::vars{'ScriptName'}?&page=$main::vars{'PageName'}&amp;filename=$elements[0]&amp;adon=upl&amp;acmd=delupload\" rel=\"nofollow\">X</a>] ";
				$confer =~ s/[\[\]]+//g;
			}
	

			my $filenum = @filedatas;
			$main::vars{'HtmlBody'} .= '</section><section><h2>Attached File</h2>'.$confer.'</section>' if $filenum == 1;
			$main::vars{'HtmlBody'} .= '</section><section><h2>Attached Files</h2>'.$confer.'</section>' if $filenum > 1;
		}
		$main::vars{'MetaInfo'} = "Last-modified: $modified, Created: $created, Tags: $hash_ofpage->{'tags'}, AutoTags: $hash_ofpage->{'autotags'}<br />$hash_ofpage->{'copyright'}<br />";
	} else {
		$main::vars{'HtmlHead'} .= '<title>Not Found'.'@'.$main::vars{'SiteName'}.'</title>';
		$main::vars{'HtmlBody'} .= "KeiSpade does not have a page with this exact name. <a href=\"$main::vars{'ScriptName'}?page=$main::vars{'PageName'}&cmd=new\">Write the $main::vars{'PageName'}</a>.";
		$main::vars{'HttpStatus'} = 'Status: 404 Not Found';
	}
	KSpade::Show::html('html/body.html',\%main::vars);
}

sub atom {
	my $pupdated = ($sql->fetch("select lastmodified_date from pages order by lastmodified_date desc limit 1"))[0];
	$pupdated= KSpade::DateTime::spridtarg($pupdated);
	chomp $pupdated;
	my $hash_ref = ($sql->fetch_ashash("select * from pages order by lastmodified_date desc limit 5;"));
	$main::vars{'AtomUpdated'} = $pupdated;
	my ($title, $etitle, $id, $link, $update, $publish, $tags, $author, $body, $pbody, $tmp);
	my $entry = '';
	$main::vars{'AtomEntries'} .= "<id>${abspath}$main::vars{'ScriptName'}?cmd=atom</id>";
	foreach my $keys (keys %$hash_ref) {
		$title  = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'title'};
		$etitle = KSpade::Misc::urlenc($title);
		$id     = "${abspath}$main::vars{'ScriptName'}?page=$etitle";
		$link   = "./$main::vars{'ScriptName'}?page=$etitle";
		$update = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'lastmodified_date'};
		$publish= $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'created_date'};
		$tags   = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'tags'};
		$author   = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'author'};
		$author = $main::vars{'DefaultAuthor'} if not defined $author;
		$body   = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'body'};
		$body = 'No text' if $body eq '';
		require 'Text/HatenaEx.pm';
		$pbody = KSpade::Security::ahtml(Text::HatenaEx->parse(KSpade::Security::html(KSpade::Security::noscript($body))));
		my @tag = split(/\|/,$tags);
		my $ptag = '';
		foreach my $tmp (@tag) {
			$ptag .= "<category term=\"$tmp\" />";
		}
		$update  = KSpade::DateTime::spridtarg($update);
		$publish = KSpade::DateTime::spridtarg($publish);
		$main::vars{'AtomEntries'} .= "<entry><title>$title</title><id>$id</id><author><name>$author</name></author>".
		                        "<link rel=\"alternate\" href=\"$link\" />".
		                        "<updated>$update</updated><published>$publish</published>$ptag".
		                        "<content type=\"html\">$pbody</content></entry>\n";
	}
	KSpade::Show::xml('html/atom.xml',\%main::vars);
}

# print edit page form
sub edit {
	my @res = ($sql->fetch("select body from pages where title='$main::vars{'PageName'}';"));
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
		my @res = ($sql->fetch("select * from pages where title='".$main::vars{'PageName'}."';"));
		my $hashparent = &sha::pureperl($res[7]);
		if (($page{'bodyhash'} eq $hashparent) or ($page{'bodyhash'} =~ /Conflict/)) {
			$page{'title'} = 'undefined'.rand(16384) if $page{'title'} eq '';
			$sql->do("update pages set title='$page{'title'}', lastmodified_date='$page{'modified_date'}', tags='$page{'tags'}',".
				     "autotags='$page{'autotags'}', copyright='$page{'copyright'}', body='$page{'body'}' where title='".$main::vars{'PageName'}."';");
			if ($pagename eq $page{'title'}) {
				KSpade::Misc::setpagename($page{'title'});
				&page;
			}
			$main::vars{'HttpStatus'} = 'Status: 303 See Other';
			$main::vars{'HttpStatus'} .= "\nLocation: $main::vars{'ScriptAbsolutePath'}$main::vars{'ScriptName'}?page=$main::vars{'PageName'}";
		} else {
			require Text::Diff;
			my $diff = Text::Diff::diff(\$res[7],\$page{'body'});
			$diff =~ s/\n/<br \/>/g;
			$main::vars{'Diff'} = $diff;
			$main::vars{'Body'} = $res[7];
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

	#$main::vars{'HtmlHead'} .= '<title>'.$page{'title'}.'@'.$main::vars{'SiteName'}.'</title>';

	require 'Text/HatenaEx.pm';
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
		my @res = ($sql->fetch("select count(*) from pages where title='".$page{'title'}."';"));
		$page{'title'} = $page{'title'}.rand(16384) unless $res[0] == 0;
		$page{'title'} = 'undefined'.rand(16384) if $page{'title'} eq '';
		$main::vars{'PageName'} = $page{'title'};
		$sql->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
			values ('$page{'title'}','$page{'created_date'}','$page{'created_date'}','$page{'tags'}','$page{'autotags'}','$page{'copyright'}','$page{'body'}');");
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
		$sql->do("delete from pages where title='".$main::vars{'PageName'}."'");
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
		$main::vars{'PagesList'} = KSpade::Show::pageslist("select title from pages where body like '%$query%';"
			,"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
		$main::vars{'HtmlHead'} .= '<title>Search &gt; Body@'.$main::vars{'SiteName'}.'</title>';
		$main::vars{'HtmlBody'} .= KSpade::Show::template('html/search.html',\%vars);
		delete $main::vars{'PagesList'};

	}
	# print all pages
	else {
		$main::vars{'PagesList'} = KSpade::Show::pageslist("select title from pages;"
			,"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
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
		$main::vars{'CategoryTitle'} = "Index of Categories";
		$main::vars{'CategoryList'} = '<ul>';
		$main::vars{'CategoryList'} .= KSpade::Show::categorylist("select tags from pages;"
		,"<li><a href=\"./$main::vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></li>");
		$main::vars{'CategoryList'} .= '</ul>';
	} else {
		$main::vars{'CategoryTitle'} = "Pages related to '$main::vars{'Query'}'";
		$main::vars{'CategoryList'} = KSpade::Show::categorylist("select title from pages where tags like '%$query%';"
			,"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
	}
	$main::vars{'HtmlHead'} .= '<title>Search &gt; Category@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/category.html',\%vars);
	delete $main::vars{'CategoryTitle'};
	delete $main::vars{'CategoryList'};
	delete $main::vars{'Query'};
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
} 

