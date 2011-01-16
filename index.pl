#!/usr/bin/perl

use strict;
use warnings;

# include modules
use File::Basename qw(basename);

use lib './lib';
use HTML::Template;
use SQL;
use Time::Local;
require 'cgidec.pl';
require 'date.pl';
require 'kscconf.pl';
require 'security.pl';

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
my %vars = ( 'SiteName'=>'KeiSpade','SiteDescription'=>'The Multimedia Wiki','ScriptName'=>$myname,'UploaderName'=>'upload.pl',
             'ScriptAbsolutePath'=>$abspath, 'SidebarPagesListLimit'=>'10','ContentLanguage'=>'ja' );
%vars = (%vars, &kscconf::load('./dat/kspade.conf'));
$vars{'Version'}  = '0.4.0';

# http header + html meta header
my $httpstatus = "Status: 200 OK";
my $contype = "Content-Type: text/html; charset=UTF-8";
$vars{'HtmlHead'} = '<meta charset=utf-8 /><link href="./css/kspade.css" rel="stylesheet" type="text/css" media="screen,print">';
$vars{'HtmlHead'} .= "<link rel=\"contents\" href=\"./$vars{'ScriptName'}?cmd=search\">";
$vars{'HtmlHead'} .= "<link rel=\"start\" href=\"./$vars{'ScriptName'}?page=TopPage\">";
$vars{'HtmlHead'} .= "<link rel=\"index\" href=\"./$vars{'ScriptName'}?cmd=category\">";

# process cgi args
my %query = &getline($ENV{'QUERY_STRING'});

&setpagename($query{'page'});

sub setpagename {
	$vars{'PageName'} = &exorcism($_[0]);
	if (not defined $vars{'PageName'} or not $vars{'PageName'} =~ /.+/) {
		$vars{'PageName'} = 'TopPage'
	}
	$vars{'NoSpacePageName'} = $vars{'PageName'};
	$vars{'NoSpacePageName'} =~ tr/ /+/;
}

# connect to DB
my $database = './dat/kspade.db';
my $data_source = "dbi:SQLite:dbname=$database";
my $sql = SQL->new($data_source);

if ($sql->tableexists == 0) {
	# database initialize (create the table)
	$sql->create_table;
	my $modified_date = time();
	my $created_date = $modified_date;
	my $body = &tmpl2html('html/tutorial.txt',\%vars);
	$sql->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
		values ('TopPage','$modified_date','$created_date','Help','Help','Copyleft','$body');");
	$vars{'HtmlHead'} .= '<link href="./css/light.css" rel="stylesheet" type="text/css">';
	$vars{'HtmlHead'} .= '<title>Miracle! Table was created!</title>';
	$vars{'HtmlBody'} .= '<p>Table was created. Please reload.</p>';
}




if ((not defined $query{'cmd'}) and (defined $vars{'PageName'})) {
	&page;
} elsif (defined $query{'cmd'}) {
	no strict 'refs';
	&{$query{'cmd'}};
}

# print page
sub page { 
	my $hash_ref = ($sql->fetch_ashash("select * from pages where title='".$vars{'PageName'}."';"));
	my $hash_ofpage = $hash_ref->{$vars{'PageName'}};
	if (defined $hash_ofpage->{'title'}) {
		my $tags = $hash_ofpage->{'tags'};
		chop $tags;

		my $modified = &relative_time($hash_ofpage->{'lastmodified_date'});
		my $created = &relative_time($hash_ofpage->{'created_date'});

		$vars{'HtmlHead'} .= '<title>'.$hash_ofpage->{'title'}.'@'.$vars{'SiteName'}.'</title>';

		require 'Text/HatenaEx.pm';
		$vars{'HtmlBody'} .= "<h2>$hash_ofpage->{'title'}</h2>";
		my $parsed = '';
		$parsed .= Text::HatenaEx->parse(&noscript($hash_ofpage->{'body'}));
		$vars{'HtmlBody'} .= $parsed;

		my $confer;
		if (defined $hash_ofpage->{'confer'}) {
			my @filedatas= split(/\]\[/, $hash_ofpage->{'confer'});
			foreach my $filedata (@filedatas) {
				my @elements = split(/\//, $filedata);
				$confer .= "<a href=\"files/$elements[0]\">$elements[1]</a> [<a href=\"./$vars{'ScriptName'}?&page=$vars{'PageName'}&amp;filename=$elements[0]&amp;cmd=delupload\" rel=\"nofollow\">X</a>] ";
				$confer =~ s/[\[\]]+//g;
			}
	

			my $filenum = @filedatas;
			$vars{'HtmlBody'} .= '</section><section><h2>Attached File</h2>'.$confer.'</section>' if $filenum == 1;
			$vars{'HtmlBody'} .= '</section><section><h2>Attached Files</h2>'.$confer.'</section>' if $filenum > 1;
		}
		$vars{'MetaInfo'} = "Last-modified: $modified, Created: $created, Tags: $hash_ofpage->{'tags'}, AutoTags: $hash_ofpage->{'autotags'}<br />$hash_ofpage->{'copyright'}<br />";
	} else {
		$vars{'HtmlHead'} .= '<title>Not Found'.'@'.$vars{'SiteName'}.'</title>';
		$vars{'HtmlBody'} .= "KeiSpade does not have a page with this exact name. <a href=\"$vars{'ScriptName'}?$vars{'PageName'}&cmd=new\">Write the $vars{'PageName'}</a>.";
		$httpstatus = 'Status: 404 Not Found';
	}
	&showhtml('html/body.html');
}
sub atom {
	my $pupdated = ($sql->fetch("select lastmodified_date from pages order by lastmodified_date desc limit 1"))[0];
	$pupdated= &spridtarg($pupdated);
	chomp $pupdated;
	my $hash_ref = ($sql->fetch_ashash("select * from pages order by lastmodified_date desc limit 5;"));
	$vars{'AtomUpdated'} = $pupdated;
	my ($title, $etitle, $id, $link, $update, $publish, $tags, $author, $body, $pbody, $tmp);
	my $entry = '';
	$vars{'AtomEntries'} .= "<id>${abspath}$vars{'ScriptName'}?cmd=atom</id>";
	foreach my $keys (keys %$hash_ref) {
		$title  = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'title'};
		$etitle = &urlenc($title);
		$id     = "${abspath}$vars{'ScriptName'}?page=$etitle";
		$link   = "./$vars{'ScriptName'}?page=$etitle";
		$update = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'lastmodified_date'};
		$publish= $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'created_date'};
		$tags   = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'tags'};
		$author   = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'author'};
		$author = 'anonymous' if not defined $author;
		$body   = $hash_ref->{$hash_ref->{$keys}->{'title'}}->{'body'};
		$body = 'No text' if $body eq '';
		require 'Text/HatenaEx.pm';
		$pbody = &html(Text::HatenaEx->parse(&html(&noscript($body))));
		my @tag = split(/\|/,$tags);
		my $ptag = '';
		foreach my $tmp (@tag) {
			$ptag .= "<category term=\"$tmp\" />";
		}
#		$tmp = spridatearg('%02d-%02d-%02d',$update);
#		$update = $tmp.'T'.spritimearg('%02d:%02d:%02d',$update).&localtz;
#		$tmp = spridatearg('%02d-%02d-%02d',$publish);
#		$publish = $tmp.'T'.spritimearg('%02d:%02d:%02d',$publish).&localtz;
		$update  = &spridtarg($update);
		$publish = &spridtarg($publish);
		$vars{'AtomEntries'} .= "<entry><title>$title</title><id>$id</id><author><name>$author</name></author><link rel=\"alternate\" href=\"$link\" />".
		                         "<updated>$update</updated><published>$publish</published>$ptag".
                                 "<content type=\"html\">$pbody</content></entry>\n";
	}
print "$httpstatus\n$contype\n\n";
print &tmpl2html('html/atom.xml',\%vars);
}
sub edit {
# print edit page form
	my @res = ($sql->fetch("select body from pages where title='$vars{'PageName'}';"));
	#$res[0] =~ s/<br \/>/\n/g;
	$vars{'DBody'} = $res[0];
	require 'sha.pl';
	$vars{'BodyHash'} = &sha::pureperl($res[0]);
	#$vars{'Token'} = rand)
	$vars{'HtmlHead'} .= '<meta http-equiv="Expires" content="0">';
	$vars{'HtmlHead'} .= '<title>'.$vars{'PageName'}.' &gt; Edit@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/editbody.html',\%vars);
	delete $vars{'DBody'};
	&showhtml;
} 
sub post {
# submit edited text
	my $pagename = $vars{'PageName'};



	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		my %page = &fetch2edit();
		require 'sha.pl';
		my @res = ($sql->fetch("select * from pages where title='".$vars{'PageName'}."';"));
		my $hashparent = &sha::pureperl($res[7]);
		if (($page{'bodyhash'} eq $hashparent) or ($page{'bodyhash'} =~ /Conflict/)) {
			$page{'title'} = 'undefined'.rand(16384) if $page{'title'} eq '';
			$sql->do("update pages set title='$page{'title'}', lastmodified_date='$page{'modified_date'}', tags='$page{'tags'}',
				autotags='$page{'autotags'}', copyright='$page{'copyright'}', body='$page{'body'}' where title='".$vars{'PageName'}."';");
			if ($pagename eq $page{'title'}) {
				&setpagename($page{'title'});
				&page;
			}
			$httpstatus = 'Status: 303 See Other';
			$httpstatus .= "\nLocation: $vars{'ScriptAbsolutePath'}$vars{'ScriptName'}?page=$vars{'PageName'}";
		} else {
			require Text::Diff;
			my $diff = Text::Diff::diff(\$res[7],\$page{'body'});
			$diff =~ s/\n/<br \/>/g;
			$vars{'Diff'} = $diff;
			$vars{'Body'} = $res[7];
			$vars{'DBody'} = $page{'body'};
			$vars{'HtmlHead'} .= '<title>'.$vars{'PageName'}.' &gt; Error@'.$vars{'SiteName'}.'</title>';
			$vars{'HtmlBody'} .= &tmpl2html('html/conflict.html',\%vars);
			delete $vars{'Diff'};
			delete $vars{'Body'};
		}
	}
	&showhtml;
} 
sub preview {
# submit edited text
	my $pagename = $vars{'PageName'};

	my %page = &fetch2edit();
	if ($pagename eq $page{'title'}) {
		&setpagename($page{'title'});
		&page;
	}

	$vars{'HtmlHead'} .= '<title>'.$page{'title'}.'@'.$vars{'SiteName'}.'</title>';

	require 'Text/HatenaEx.pm';
	$vars{'HtmlBody'} .= "<h2>$page{'title'}</h2>";
	my $parsed .= Text::HatenaEx->parse(&noscript($page{'body'}));
	$vars{'HtmlBody'} .= $parsed;
	&showhtml;
} 
sub new {
# print new page form
	$vars{'HtmlHead'} .= '<meta http-equiv="Pragma" content="no-cache">';
	$vars{'HtmlHead'} .= '<title> New@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/newbody.html',\%vars);
	&showhtml;
}
sub newpost {
# submit new page
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		my %page = &fetch2edit();
		my @res = ($sql->fetch("select count(*) from pages where title='".$page{'title'}."';"));
		$page{'title'} = $page{'title'}.rand(16384) unless $res[0] == 0;
		$page{'title'} = 'undefined'.rand(16384) if $page{'title'} eq '';
		$vars{'PageName'} = $page{'title'};
		$sql->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
			values ('$page{'title'}','$page{'created_date'}','$page{'created_date'}','$page{'tags'}','$page{'autotags'}','$page{'copyright'}','$page{'body'}');");
		&setpagename($vars{'PageName'});
		$httpstatus = 'Status: 303 See Other';
		$httpstatus .= "\nLocation: ${abspath}$vars{'ScriptName'}?page=$vars{'PageName'}";
		#&page;
	}
	&showhtml;
}
sub del {
# print delete confirm
	$vars{'HtmlHead'} .= '<title>'.$vars{'PageName'}.' &gt; Delete@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/delete.html',\%vars);
	&showhtml;
}
sub delpage {
# delete page
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		$sql->do("delete from pages where title='".$vars{'PageName'}."'");
	}
	$vars{'HtmlHead'} .= '<title>'.$vars{'PageName'}.' &gt; Deleted@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/deleted.html',\%vars);
	&showhtml;
}
sub search {
	my $query = &htmlexor($query{'query'});
	$query =~ s/\s/AND/g if defined $query;
	$vars{'Query'} = $query{'query'};
	if (defined $query{'query'}) {
		# normal search
		$vars{'PagesList'} = &listpages("select title from pages where body like '%$query%';"
			,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
		$vars{'HtmlHead'} .= '<title>Search &gt; Body@'.$vars{'SiteName'}.'</title>';
		$vars{'HtmlBody'} .= &tmpl2html('html/search.html',\%vars);
		delete $vars{'PagesList'};

	} else {
		# print all pages
		$vars{'PagesList'} = &listpages("select title from pages;"
			,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
		$vars{'HtmlHead'} .= '<title>PagesList@'.$vars{'SiteName'}.'</title>';
		$vars{'HtmlBody'} .= &tmpl2html('html/list.html',\%vars);
		delete $vars{'PagesList'};
	}
	delete $vars{'Query'};
	&showhtml;
} 
sub category {
	# print categories
	my $query = &htmlexor($query{'query'});
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
	$vars{'HtmlHead'} .= '<title>Search &gt; Category@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/category.html',\%vars);
	delete $vars{'CategoryTitle'};
	delete $vars{'CategoryList'};
	delete $vars{'Query'};
	&showhtml;
} 
sub upload {
	# print upload form
	$vars{'HtmlHead'} .= '<title>'.$vars{'PageName'}. ' &gt; Upload@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/upload.html',\%vars);

	&showhtml;
} 
sub delupload {
# print delete confirm
	my $filename = &htmlexor($query{'filename'});
	$vars{'DeleteFileName'} = $filename;
	#$vars{'PagesList'} = &listpages("select title from pages where confer like '%$filename%';");
	my @pages = $sql->fetch("select title from pages where confer like '%$filename%';");
	$vars{'PagesList'} = &listpages("select title from pages where confer like '%$filename%';"
		,"<a href=\"./$vars{'ScriptName'}?page=%s\">%s</a><br />");
	$vars{'HtmlHead'} .= '<title>'.$filename. ' &gt; Delete Uploaded Files@'.$vars{'SiteName'}.'</title>';
	$vars{'HtmlBody'} .= &tmpl2html('html/delupload.html',\%vars);
	&showhtml;
}

sub delfile {
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	my $filename = &htmlexor($query{'filename'});
	my @pages = $sql->fetch("select title from pages where confer like '%$filename%';",0);
	foreach my $tmp (@pages) {
		my @files = $sql->fetch("select confer from pages where title='$tmp';");
		$files[0] =~ s/\[$filename\/.+?\]//g;
		unlink('./files/'.$filename);
		my $modifieddate = time();
		$sql->do("update pages set lastmodified_date='$modifieddate', confer='$files[0]' where title='$tmp';");
	}
	&setpagename($vars{'PageName'});
	&page;
	}
	&showhtml;
}

sub addfile {
	# submit file
	my %page = &fetch2edit();

	$vars{'HtmlHead'} .= '<title>'.$vars{'PageName'}. ' &gt; UploadProcess@'.$vars{'SiteName'}.'</title>';
	my $filename = &htmlexor($query{'filename'});
	my $original = &htmlexor($query{'orig'});
	my @res = ($sql->fetch("select confer from pages where title='$vars{'PageName'}';"));
	my $files = $res[0];
	if ($files =~ /$filename/) {

	} else {
		my $tmp  = &spridate('%04d %2d %2d %2d:%02d:%02d');
		$files .= "[$filename/$original($tmp)]";
		$sql->do("update pages set lastmodified_date='$page{'modified_date'}', confer='$files' where title='$vars{'PageName'}';");
	}
	&showhtml;
}

sub showhtml {
	$vars{'SidebarCategoryList'} = &listcategory("select tags from pages;"
		,"<dd><a href=\"./$vars{'ScriptName'}?cmd=category&amp;query=%s\">%s</a></dd>");
	$vars{'SidebarPagesList'} = &listpages("select title from pages order by lastmodified_date desc, title limit $vars{'SidebarPagesListLimit'};"
		,"<dd><a href=\"./$vars{'ScriptName'}?page=%s\">%s</a></dd>");
	my $html;
	if (defined $_[0]) {
		$html = &tmpl2html($_[0],\%vars);
	} else {
		$html = &tmpl2html('html/frmwrk.html',\%vars);
	}
	print "$httpstatus\n$contype\n\n";
	print $html;
}

# ページ編集・作成用共通サブルーチン
sub fetch2edit {
	my %args = ();
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = &getline($postdata);

	$args{'title'} = &textalize(&exorcism($form{'title'}));
	$args{'modified_date'} = time();
	$args{'created_date'} = time();
	$args{'tags'} = '';
	$args{'autotags'} = '';
	$args{'confer'} = '';
	$args{'copyright'} = '';
	$args{'body'} = &exorcism($form{'body'});
	$args{'bodyhash'} = &exorcism($form{'bodyhash'});

	$args{'title'} =~ s/ +$// if defined $args{'title'};

	my $tagstr = $args{'title'};
	if (defined $tagstr) {
		$tagstr =~ s/^\[(.+)\](.+)/$1/g;
		if (defined $2) {
			my @tagstrs= split(/\]\[/, $tagstr);
			foreach my $tag (@tagstrs) {
				$tag =~ s/[\[\]]+//g;
				$args{'tags'} .= $tag.'|';
			}
		}
	}

	chomp(%args);
	return(%args);
}

sub listpages {
	my @res = ($sql->fetch($_[0],0));
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
	my @res = ($sql->fetch($_[0],0));
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
		return 'Today '.spritimearg('%02d:%02d:%02d',$_[0])
	} elsif ($elapsed > 86400 and $elapsed <= 172800) {
		return 'Yesterday '.spritimearg('%02d:%02d:%02d',$_[0])
	} else {
		return spridatearg('%04d/%02d/%02d',$_[0])
		.' '.spritimearg('%02d:%02d:%02d',$_[0]);
	}

}

sub urlenc {
my $string = $_[0];
$string =~ s/([^\w ])/'%'.unpack('H2', $1)/eg;
$string =~ tr/ /+/;
return $string
}
