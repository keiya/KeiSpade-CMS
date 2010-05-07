#!/usr/bin/perl

use strict;
use warnings;

# include modules
use DBI;
use lib './lib';

use HTML::Template;
require 'cgidec.pl';
require 'security.pl';
require 'sql.pl';
require 'date.pl';

my $VER = '0.0.1';
my $conf_site = 'keiyac.org';
my $conf_desc = 'i\'m hackin\' it';
my %vars = ('SiteName'=>'keiyac.org','SiteDescription'=>'i\'m hackin\' it');

# http header + html meta header
print "Content-Type: text/html; charset=UTF-8\n\n";
my $htmlhead = "<meta charset=utf-8 /><link href=\"./css/kspade.css\" rel=\"stylesheet\" type=\"text/css\" media=\"screen,print\">";

my ($htmlbdhd, $htmlbody, $sidebar, $htmlfoot);
my $notable = 0;

# process cgi args
my %query = &cgidec::getline($ENV{'QUERY_STRING'});
$vars{'PageName'} = &security::exorcism($query{'page'});
$vars{'PageName'} = 'TopPage' unless $vars{'PageName'} =~ /.+/;
$vars{'NoSpacePageName'} = $vars{'PageName'};
$vars{'NoSpacePageName'} =~ tr/ /+/;

# connect to DB
my $database = "./dat/kspade.db";
my $data_source = "dbi:SQLite:dbname=$database";

# read templates
$htmlbdhd .= &tmpl2html('html/bodyhead.html',\%vars);
$sidebar  .= &tmpl2html('html/sidebar.html',\%vars);

if ((defined $query{'init'} and $query{'init'} eq 'yes') and (&sql::tableexists($data_source) == 0)) {
# database initialize (create the table)
	&sql::create_table($data_source);
	my $modified_date = &date::spridate('%04d/%02d/%02d %02d:%02d:%02d');
	my $created_date = $modified_date;
	my $body = &tmpl2html('html/tutorial.txt',\%vars);
	&sql::do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
	          values ('TopPage','$modified_date','$created_date','Help','Help','Copyleft','$body');"
	          ,$data_source);
	$htmlhead .= '<title>Miracle! Table was created!</title>';
	$htmlbody .= '<p>Table was created. Please reload.</p>';
}

if ((not defined $query{'cmd'}) and (defined $vars{'PageName'})) {
# print page
	my @res = (&sql::fetch("select * from pages where title='$vars{'PageName'}';",$data_source));
	$htmlhead .= '<title>'.$res[0].'@'.$conf_site.'</title>';

	require 'Text/Hatena.pm';
	$htmlbody .= "<h2>$res[0]</h2>";
	$htmlbody .= Text::Hatena->parse($res[7]);

	my $confer;
	my @files = split(/\t/, $res[5]);
	foreach my $file (@files) {
		my @elements = split(/\//, $file);
		$confer .= "<a href=\"files/$elements[0]\">$elements[1]</a> ";
	}
	my $filenum = @files;
	$htmlbody .= '</section><section><h2>Attached File</h2>'.$confer.'</section>' if $filenum == 1;
	$htmlbody .= '</section><section><h2>Attached Files</h2>'.$confer.'</section>' if $filenum > 1;

	$htmlfoot .= "Last-modified: $res[1], Created: $res[2], Tags: $res[3], AutoTags: $res[4]<br />$res[6]<br />";

} elsif ($query{'cmd'} eq 'edit') {
# print edit page form
	my @res = (&sql::fetch("select body from pages where title='$vars{'PageName'}';",$data_source));
	$res[0] =~ s/<br \/>/\n/g;
	$vars{'DBody'} = $res[0];
	$htmlhead .= '<title>'.$vars{'PageName'}.' &gt; Edit@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/editbody.html',\%vars);
	delete $vars{'DBody'};

} elsif ($query{'cmd'} eq 'post') {
# submit edited text
	my $pagename = $vars{'PageName'};
	my ($title,$modifieddate,$tags,$autotags,$copyright,$body) = (&edit)[0,1,3,4,6,7];
	&sql::do("update pages set title='$title', lastmodified_date='$modifieddate', tags='$tags',
	          autotags='$autotags', copyright='$copyright', body='$body' where title='$pagename';"
	          ,$data_source);

} elsif ($query{'cmd'} eq 'new') {
# print new page form
	$htmlhead .= '<title> New@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/newbody.html',\%vars);

} elsif ($query{'cmd'} eq 'newpost') {
# submit new page
	my ($title,$modified_date,$created_date,$tags,$autotags,$copyright,$body) = (&edit)[0,1,2,3,4,6,7];	
	$title = 'undefined'.rand(16384) if $title eq '';
	&sql::do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)
	          values ('$title','$modified_date','$created_date','$tags','$autotags','$copyright','$body');"
	          ,$data_source);

} elsif ($query{'cmd'} eq 'del') {
# print delete confirm

	$htmlhead .= '<title>'.$vars{'PageName'}.' &gt; Delete@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/delete.html',\%vars);

} elsif ($query{'cmd'} eq 'delpage') {
# delete page
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = &cgidec::getline($postdata);
		&sql::do("delete from pages where title='$vars{'PageName'}'",$data_source);

} elsif ($query{'cmd'} eq 'search') {
	my $query = &security::textalize(&security::exorcism($query{'query'}));
	$query =~ s/\s/AND/g;
		$vars{'Query'} = $query{'query'};
	if (defined $query{'query'}) {
	# normal search
		$vars{'PagesList'} = &listpages("select title from pages where body like '%$query%';"
	                                        ,"<a href=\"./index.pl?page=%s\">%s</a><br />") if defined $query{'query'};
		$htmlhead .= '<title>Search &gt; Body@'.$vars{'SiteName'}.'</title>';
		$htmlbody .= &tmpl2html('html/search.html',\%vars);
		delete $vars{'PagesList'};

	} else {
	# print all pages
		$vars{'PagesList'} = &listpages("select title from pages;"
	                                        ,"<a href=\"./index.pl?page=%s\">%s</a><br />") if not defined $query{'query'};
		$htmlhead .= '<title>PagesList@'.$vars{'SiteName'}.'</title>';
		$htmlbody .= &tmpl2html('html/list.html',\%vars);
		delete $vars{'PagesList'};
	}
	delete $vars{'Query'};

} elsif ($query{'cmd'} eq 'category') {
# print categories
	my $query = &security::textalize(&security::exorcism($query{'query'}));
	$query =~ s/\s/AND/g;
	$vars{'Query'} = $query{'query'};
	$vars{'CategoryList'} = &listcategory("select title from pages where tags like '%$query%';"
	                                      ,"<a href=\"./index.pl?page=%s\">%s</a><br />");
	$htmlhead .= '<title>Search &gt; Category@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/category.html',\%vars);
	delete $vars{'CategoryList'};
	delete $vars{'Query'};

} elsif ($query{'cmd'} eq 'upload') {
# print upload form
	$htmlhead .= '<title>'.$vars{'PageName'}. ' &gt; Upload@'.$vars{'SiteName'}.'</title>';
	$htmlbody .= &tmpl2html('html/upload.html',\%vars);

} elsif ($query{'cmd'} eq 'addfile') {
# submit file
	my ($modifieddate,$file,$body);
	$modifieddate = &date::spridate('%04d/%02d/%02d %02d:%02d:%02d');
	$htmlhead .= '<title>'.$vars{'PageName'}. ' &gt; UploadProcess@'.$vars{'SiteName'}.'</title>';
	my $filename = &security::html(&security::exorcism($query{'filename'}));
	my $original = &security::html(&security::exorcism($query{'orig'}));
	my @res = (&sql::fetch("select confer from pages where title='$vars{'PageName'}';",$data_source));

	$file = $res[0]."$filename/$original\t";

	&sql::do("update pages set lastmodified_date='$modifieddate', confer='$file' where title='$vars{'PageName'}';"
	         ,$data_source);
} else {
}

if ($notable == 0) {
	my $categorylist = &listcategory("select tags from pages;"
	                                 ,"<dd><a href=\"./index.pl?cmd=category&amp;query=%s\">%s</a></dd>");
	my $pageslist = &listpages("select title from pages order by lastmodified_date desc, title limit 5;"
	                           ,"<dd><a href=\"./index.pl?page=%s\">%s</a></dd>");
	$sidebar .= "<dt>Category</dt>$categorylist";
	$sidebar .= "<dt>Pages</dt>$pageslist";
}

my $ad = <<__EOD__;
<script>
google_ad_client = "pub-7822764449175755";
/* 336x280, 作成済み 10/02/25 */
google_ad_slot = "8782365220";
google_ad_width = 336;
google_ad_height = 280;
</script>
<script src="http://pagead2.googlesyndication.com/pagead/show_ads.js"></script>
__EOD__

$htmlfoot .= "<hr /><address>KeiSpade CMS $VER by Keiya Chinen</address>";
print '<!DOCTYPE html><head>'.$htmlhead.'</head><body><header>'.$htmlbdhd.'</header><div id="container"><div id="main_container"><section>'.$htmlbody.'</section><hr /><section>'.$ad.'</section></div><aside><dl id="page_menu">'.$sidebar.'</dl></aside></div><footer>'.$htmlfoot.'</footer>';
print "</body></html>";


# ページ編集・作成用共通サブルーチン
sub edit {
	my ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body);
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = &cgidec::getline($postdata);
	$body = &security::html(&security::exorcism($form{'body'}));
	$title = &security::textalize(&security::exorcism($form{'title'}));

	my $tagstr = $title;
	$tagstr =~ s/^\[(.+)\](.+)/$1/g;
	if (defined $2) {
		my @tagstrs= split(/\]\[/, $tagstr);
		foreach my $tag (@tagstrs) {
			$tag =~ s/[\[\]]+//g;
			$tags .= $tag.'|';
		}
	}
	$modified_date = &date::spridate('%04d/%02d/%02d %02d:%02d:%02d');
	$created_date = $modified_date;
	return ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body);
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

sub sha2 {
	require Digest::SHA::PurePerl;
	my $sha = Digest::SHA::PurePerl->new(256);
	return $sha->add($_[0])->hexdigest;
}

sub tmpl2html {
		my $template = HTML::Template->new(filename => $_[0],die_on_bad_params => 0,cache => 1);
		$template->param(%{$_[1]});
		return $template->output;
}

