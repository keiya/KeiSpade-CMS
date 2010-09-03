#!/usr/bin/perl

use strict;
use warnings;

# include modules
use File::Basename qw(basename);
use DBI;
use lib './lib';

use HTML::Template;
require 'cgidec.pl';
require 'security.pl';
require 'sql.pl';
require 'date.pl';
require 'kscconf.pl';

# script file name
my $myname = basename($0, '');

my $VER = '0.1.0';
my %vars = ('SiteName'=>'KeiSpade','SiteDescription'=>'The Multimedia Wiki','ScriptName'=>$myname,'UploaderName'=>'upload.pl',
	'SidebarPagesListLimit'=>'10','ContentLanguage'=>'ja');
%vars = (%vars, &kscconf::load('./dat/kspade.conf'));

# http header + html meta header
print "Content-Type: text/html; charset=UTF-8\n\n";
my $htmlhead = '<meta charset=utf-8 /><link href="./css/kspade.css" rel="stylesheet" type="text/css" media="screen,print">';
$htmlhead .= "<link rel=\"contents\" href=\"./$vars{'ScriptName'}?cmd=search\">";
$htmlhead .= "<link rel=\"start\" href=\"./$vars{'ScriptName'}?page=TopPage\">";
$htmlhead .= "<link rel=\"index\" href=\"./$vars{'ScriptName'}?cmd=category\">";

my ($htmlbdhd, $htmlbody, $sidebar, $htmlfoot) = ( '', '', '', '');

# process cgi args
my %query = &cgidec::getline($ENV{'QUERY_STRING'});

&setpagename($query{'page'});

sub setpagename {
	$vars{'PageName'} = &security::exorcism($_[0]);
	if (not defined $vars{'PageName'} or not $vars{'PageName'} =~ /.+/) {
		$vars{'PageName'} = 'TopPage'
	}
	$vars{'NoSpacePageName'} = $vars{'PageName'};
	$vars{'NoSpacePageName'} =~ tr/ /+/;
}

# connect to DB
my $database = './dat/kspade.db';
my $dbargs = {PrintError=>1};
my $data_source = "dbi:SQLite:dbname=$database";

if (
	(defined $query{'init'} and $query{'init'} eq 'yes')
	and (&sql::tableexists($data_source) == 0))
	{
# database initialize (create the table)
	&sql::create_table($data_source);
	my $modified_date = time();
	my $created_date = $modified_date;
	my $body = &tmpl2html('html/tutorial.txt',\%vars);
	&sql::do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
		values ('TopPage','$modified_date','$created_date','Help','Help','Copyleft','$body');"
		,$data_source);
	$htmlhead .= '<link href="./css/light.css" rel="stylesheet" type="text/css">';
	$htmlhead .= '<title>Miracle! Table was created!</title>';
	$htmlbody .= '<p>Table was created. Please reload.</p>';
}

$htmlbdhd .= &tmpl2html('html/bodyhead.html',\%vars);



if ((not defined $query{'cmd'}) and (defined $vars{'PageName'})) {
#if ((not defined $query{'cmd'}) ) {
	&page;
} elsif (defined $query{'cmd'}) {
	no strict 'refs';
	&{$query{'cmd'}};
}


# print page
sub page { 
	my @res = (&sql::fetch("select * from pages where title='".$vars{'PageName'}."';",$data_source));
	my $modified = $res[1];
	my $created  = $res[2];
	chop $res[3];

	$modified = &relative_time($modified);
	$created = &relative_time($created);

	$htmlhead .= '<title>'.$res[0].'@'.$vars{'SiteName'}.'</title>';

	require 'Text/HatenaEx.pm';
	$htmlbody .= "<h2>$res[0]</h2>";
	my $parsed .= Text::HatenaEx->parse(&security::noscript($res[7]));
	$htmlbody .= $parsed;

	my $confer;
	if (defined $res[5]) {
		my @filedatas= split(/\]\[/, $res[5]);
		foreach my $filedata (@filedatas) {
			my @elements = split(/\//, $filedata);
			$confer .= "<a href=\"files/$elements[0]\">$elements[1]</a> [<a href=\"./$vars{'ScriptName'}?&page=$vars{'PageName'}&amp;filename=$elements[0]&amp;cmd=delupload\" rel=\"nofollow\">X</a>] ";
			$confer =~ s/[\[\]]+//g;
		}
	

		my $filenum = @filedatas;
		$htmlbody .= '</section><section><h2>Attached File</h2>'.$confer.'</section>' if $filenum == 1;
		$htmlbody .= '</section><section><h2>Attached Files</h2>'.$confer.'</section>' if $filenum > 1;
	}
	$htmlfoot .= "Last-modified: $modified, Created: $created, Tags: $res[3], AutoTags: $res[4]<br />$res[6]<br />";
} 
sub edit {
# print edit page form
	my @res = (&sql::fetch("select body from pages where title='$vars{'PageName'}';",$data_source));
	#$res[0] =~ s/<br \/>/\n/g;
	$vars{'DBody'} = $res[0];
	require 'sha.pl';
	$vars{'BodyHash'} = &sha::pureperl($res[0]);
	#$vars{'Token'} = rand)
	$htmlhead .= '<meta http-equiv="Pragma" content="no-cache">';
	$htmlhead .= '<title>'.$vars{'PageName'}.' &gt; Edit@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/editbody.html',\%vars);
	delete $vars{'DBody'};
} 
sub post {
# submit edited text
	my $pagename = $vars{'PageName'};

	my ($title,$modifieddate,$tags,$autotags,$copyright,$body,$bodyhash) = (&fetch2edit)[0,1,3,4,6,7,8];
	require 'sha.pl';
	my @res = (&sql::fetch("select * from pages where title='".$vars{'PageName'}."';",$data_source));
	my $hashparent = &sha::pureperl($res[7]);
	if (($bodyhash eq $hashparent) or ($bodyhash =~ /Conflict/)) {
		$title = 'undefined'.rand(16384) if $title eq '';
		&sql::do("update pages set title='$title', lastmodified_date='$modifieddate', tags='$tags',
			autotags='$autotags', copyright='$copyright', body='$body' where title='".$vars{'PageName'}."';"
			,$data_source);
		if ($pagename eq $title) {
			&setpagename($title);
			&page;
		}
	} else {
		require Text::Diff;
		my $diff = Text::Diff::diff(\$res[7],\$body);
		$diff =~ s/\n/<br \/>/g;
		$vars{'Diff'} = $diff;
		$vars{'Body'} = $res[7];
		$vars{'DBody'} = $body;
		$htmlhead .= '<title>'.$vars{'PageName'}.' &gt; Error@'.$vars{'SiteName'}.'</title>';
		$htmlbody .= &tmpl2html('html/conflict.html',\%vars);
		delete $vars{'Diff'};
		delete $vars{'Body'};
	}
} 
sub preview {
# submit edited text
	my $pagename = $vars{'PageName'};

	my ($title,$modifieddate,$tags,$autotags,$copyright,$body) = (&fetch2edit)[0,1,3,4,6,7];
#	&sql::do("update pages set title='$title', lastmodified_date='$modifieddate', tags='$tags',
#		autotags='$autotags', copyright='$copyright', body='$body' where title='".$vars{'PageName'}."';"
#		,$data_source);
	if ($pagename eq $title) {
		&setpagename($title);
		&page;
	}

	$htmlhead .= '<title>'.$title.'@'.$vars{'SiteName'}.'</title>';

	require 'Text/HatenaEx.pm';
	$htmlbody .= "<h2>$title</h2>";
	my $parsed .= Text::HatenaEx->parse(&security::noscript($body));
	$htmlbody .= $parsed;
} 
sub new {
# print new page form
	$htmlhead .= '<meta http-equiv="Pragma" content="no-cache">';
	$htmlhead .= '<title> New@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/newbody.html',\%vars);
}
sub newpost {
# submit new page
	my ($title,$created_date,$tags,$autotags,$copyright,$body) = (&fetch2edit)[0,2,3,4,6,7];	
	my @res = (&sql::fetch("select count(*) from pages where title='".$title."';",$data_source));
	$title = $title.rand(16384) unless $res[0] == 0;
	$title = 'undefined'.rand(16384) if $title eq '';
	$vars{'PageName'} = $title;
	&sql::do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
		values ('$title','$created_date','$created_date','$tags','$autotags','$copyright','$body');"
		,$data_source);
	&setpagename($vars{'PageName'});
	&page;
}
sub del {
# print delete confirm

	$htmlhead .= '<title>'.$vars{'PageName'}.' &gt; Delete@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/delete.html',\%vars);
}
sub delpage {
# delete page
	#read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	#my %form = &cgidec::getline($postdata);
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		&sql::do("delete from pages where title='".$vars{'PageName'}."'",$data_source);
	}
	&setpagename('TopPage');
	&page;
}
sub search {
	my $query = &security::textalize(&security::exorcism($query{'query'}));
	$query =~ s/\s/AND/g if defined $query;
	$vars{'Query'} = $query{'query'};
	if (defined $query{'query'}) {
		# normal search
		$vars{'PagesList'} = &listpages("select title from pages where body like '%$query%';"
			,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
		$htmlhead .= '<title>Search &gt; Body@'.$vars{'SiteName'}.'</title>';
		$htmlbody .= &tmpl2html('html/search.html',\%vars);
		delete $vars{'PagesList'};

	} else {
		# print all pages
		$vars{'PagesList'} = &listpages("select title from pages;"
			,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
		$htmlhead .= '<title>PagesList@'.$vars{'SiteName'}.'</title>';
		$htmlbody .= &tmpl2html('html/list.html',\%vars);
		delete $vars{'PagesList'};
	}
	delete $vars{'Query'};

} 
sub category {
	# print categories
	my $query = &security::textalize(&security::exorcism($query{'query'}));
	$query =~ s/\s/AND/g;
	$vars{'Query'} = $query{'query'};
	if ($vars{'Query'} eq '') {
		$vars{'CategoryTitle'} = "Index of Categories";
		$vars{'CategoryList'} = '<ul>';
		$vars{'CategoryList'} .= &listcategory("select tags from pages;"
		,"<li><a href=\"./$vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></li>");
		$vars{'CategoryList'} .= '</ul>';
	} else {
		$vars{'CategoryTitle'} = "Pages related to '$vars{'Query'}'";
		$vars{'CategoryList'} = &listcategory("select title from pages where tags like '%$query%';"
			,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
	}
	$htmlhead .= '<title>Search &gt; Category@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/category.html',\%vars);
	delete $vars{'CategoryTitle'};
	delete $vars{'CategoryList'};
	delete $vars{'Query'};

} 
sub upload {
	# print upload form
	$htmlhead .= '<title>'.$vars{'PageName'}. ' &gt; Upload@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/upload.html',\%vars);

} 
sub delupload {
# print delete confirm
	my $filename = &security::html(&security::exorcism($query{'filename'}));
	$vars{'DeleteFileName'} = $filename;
	#$vars{'PagesList'} = &listpages("select title from pages where confer like '%$filename%';");
	my @pages = &sql::fetch("select title from pages where confer like '%$filename%';",$data_source);
	$vars{'PagesList'} = &listpages("select title from pages where confer like '%$filename%';"
		,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
	$htmlhead .= '<title>'.$filename. ' &gt; Delete Uploaded Files@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/delupload.html',\%vars);
}

sub delfile {
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	my $filename = &security::html(&security::exorcism($query{'filename'}));
	my @pages = &sql::fetch("select title from pages where confer like '%$filename%';",$data_source,0);
	foreach my $tmp (@pages) {
		my @files = &sql::fetch("select confer from pages where title='$tmp';",$data_source);
		$files[0] =~ s/\[$filename\/.+?\]//g;
		unlink('./files/'.$filename);
		my $modifieddate = time();
		&sql::do("update pages set lastmodified_date='$modifieddate', confer='$files[0]' where title='$tmp';"
			,$data_source);
	}
	&setpagename($vars{'PageName'});
	&page;
	}
}

sub addfile {
	# submit file
	my ($title,$modifieddate) = (&fetch2edit)[0,1];

	$htmlhead .= '<title>'.$vars{'PageName'}. ' &gt; UploadProcess@'.$vars{'SiteName'}.'</title>';
	my $filename = &security::html(&security::exorcism($query{'filename'}));
	my $original = &security::html(&security::exorcism($query{'orig'}));
	my @res = (&sql::fetch("select confer from pages where title='$vars{'PageName'}';",$data_source));
	my $files = $res[0];
	if ($files =~ /$filename/) {

	} else {
		my $tmp  = &date::spridate('%04d %2d %2d %2d:%02d:%02d');
		$files .= "[$filename/$original($tmp)]";
		&sql::do("update pages set lastmodified_date='$modifieddate', confer='$files' where title='$vars{'PageName'}';"
			,$data_source);
	}
	# TODO: これはあくまで暫定処置 いずれ全体的な構造を見直す
	$htmlbody = "";
	$sidebar = "";
}

$vars{'SidebarCategoryList'} = &listcategory("select tags from pages;"
	,"<dd><a href=\"./$vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></dd>");
$vars{'SidebarPagesList'} = &listpages("select title from pages order by lastmodified_date desc, title limit $vars{'SidebarPagesListLimit'};"
	,"<dd><a href=\"./$vars{'ScriptName'}?page=%s\">%s</a></dd>");
$sidebar  = &tmpl2html('html/sidebar.html',\%vars);
$htmlfoot .= "<hr /><address>KeiSpade CMS $VER by <a href=\"http://keispade.keiyac.org/\">KeiSpade Development Team</a></address>";
print '<!DOCTYPE html><html lang="'.$vars{'ContentLanguage'}.'"><head>'.$htmlhead.'</head><body><header>'.$htmlbdhd.'</header><div id="container"><div id="main_container"><section>'.$htmlbody.'</section><hr /></div><aside><dl id="page_menu">'.$sidebar.'</dl></aside></div><footer>'.$htmlfoot.'</footer>';
print "</body></html>";


# ページ編集・作成用共通サブルーチン
sub fetch2edit {
	my ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body) = ('','','','','','','','');
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = &cgidec::getline($postdata);
	$body = &security::exorcism($form{'body'});
	my $bodyhash = &security::exorcism($form{'bodyhash'});
	$title = &security::textalize(&security::exorcism($form{'title'}));

	my $tagstr = $title;
	if (defined $tagstr) {
	$tagstr =~ s/^\[(.+)\](.+)/$1/g;
	if (defined $2) {
		my @tagstrs= split(/\]\[/, $tagstr);
		foreach my $tag (@tagstrs) {
			$tag =~ s/[\[\]]+//g;
			$tags .= $tag.'|';
		}
	}
	}
	$modified_date = time();
	$created_date = time();

	chomp ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body,$bodyhash);
	return ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body,$bodyhash);
}

sub listpages {
	my @res = (&sql::fetch($_[0],$data_source,0));
	my $pageslist;
	my $format = $_[1];
	foreach my $tmp (@res) {
		my $formatmp = $format;
		$formatmp =~ s/%s/$tmp/g;
		$pageslist .= $formatmp;
	}
	return $pageslist;
}

sub listcategory {
	my @res = (&sql::fetch($_[0],$data_source,0));
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

sub tmpl2html {
	my $template = HTML::Template->new(filename => $_[0],die_on_bad_params => 0,cache => 1);
	$template->param(%{$_[1]});
	return $template->output;
}

sub relative_time {
	my $elapsed = time() - $_[0];

	if ($elapsed <= 86400) {
		return 'Today '.&date::spritimearg('%02d:%02d:%02d',$_[0])
	} elsif ($elapsed > 86400 and $elapsed <= 172800) {
		return 'Yesterday '.&date::spritimearg('%02d:%02d:%02d',$_[0])
	} else {
		return &date::spridatearg('%04d/%02d/%02d',$_[0])
		.' '.&date::spritimearg('%02d:%02d:%02d',$_[0]);
	}

}


