#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use lib './lib';

require 'cgidec.pl';
require 'security.pl';
require 'sql.pl';
require 'date.pl';

my $VER = '0.0.1';
my $conf_site = 'keiyac.org';
my $conf_desc = 'i\'m hackin\' it';

print "Content-Type: text/html; charset=UTF-8\n\n";
my $htmlhead = "<meta charset=utf-8 /><link href=\"./css/kspade.css\" rel=\"stylesheet\" type=\"text/css\" media=\"screen,print\">";
my ($htmlbdhd, $htmlbody, $sidebar, $htmlfoot);
my $notable = 0;

my %query = &cgidec::getline($ENV{'QUERY_STRING'});
my $pagename = &security::exorcism($query{'page'});
$pagename = 'TopPage' unless $pagename =~ /.+/;
my $pagenamens = $pagename;
$pagenamens =~ tr/ /+/;

# connect to DB
my $database = "./dat/kspade.db";
my $data_source = "dbi:SQLite:dbname=$database";

$htmlbdhd .=<<__EOM__;
<h1><span>$conf_site</span> $conf_desc</h1>
<nav>
<ul>
<li><a href="./index.pl?page=$pagenamens&amp;cmd=edit"><span>Edit</span></a></li>
<li><a href="./index.pl?cmd=new"><span>New</span></a></li>
<li><a href="./index.pl?page=$pagenamens&amp;cmd=del"><span>Delete</span></a></li>
<li><a href="./index.pl?cmd=upload&amp;page=$pagenamens"><span>Upload</span></a></li>
</ul>
</nav>
__EOM__

$sidebar.=<<__EOM__;
<dt>Search</dt>
<dd>
<form action="./index.pl" method="get" name="searchform" accept-charset="utf-8">
<input type="text" name="query" placeholder="..." size="15">
<input type="hidden" name="cmd" value="search">
<button value="Search" name="querysend" type="submit">Go</button>
</form>
</dd>
__EOM__


if ((not defined $query{'cmd'}) and (defined $query{'page'})) {
require 'convert.pl';
	my @res = (&sql::fetch("select * from pages where title='$pagename';",$data_source));
	$htmlhead .= '<title>'.$res[0].'@'.$conf_site.'</title>';
	&convert::tohtml(\$res[7]);
	$htmlbody .= "<h2>$res[0]</h2>".$res[7];
my $confer;
my @files = split(/\t/, $res[5]);
foreach my $file (@files) {
	my @elements = split(/\//, $file);
	$confer .= "<a href=\"files/$elements[0]\">$elements[1]</a> ";
}
	$htmlfoot .= "Last-modified: $res[1], Created: $res[2], Tags: $res[3], AutoTags: $res[4]<br />$res[6]<br />Cf.<br />$confer";
} elsif ($query{'cmd'} eq 'edit') {
	my @res = (&sql::fetch("select body from pages where title='$pagename';",$data_source));
	$res[0] =~ s/<br \/>/\n/g;
$htmlhead .= '<title>'.$pagename.' &gt; Edit@'.$conf_site.'</title>';
$htmlbody .=<<__EOM__;
<section><h2>Editing $pagename</h2>
<form action="./index.pl?cmd=post&amp;page=$pagenamens" method="post" name="editform" accept-charset="utf-8">
Title:<br />
<input type="text" value="$pagename" name="title"><br />
Body:<br />
<textarea name="body" rows="20" cols="80">
$res[0]
</textarea><br />
<button value="Post" name="bodysend" type="submit">Post</button>
</form>
</section>
__EOM__
} elsif ($query{'cmd'} eq 'post') {
	my ($title,$modifieddate,$tags,$autotags,$copyright,$body) = (&edit)[0,1,3,4,6,7];
	&sql::do("update pages set title='$title', lastmodified_date='$modifieddate', tags='$tags', autotags='$autotags', copyright='$copyright', body='$body' where title='$pagename';",$data_source);
} elsif ($query{'cmd'} eq 'new') {
$htmlhead .= '<title> New@'.$conf_site.'</title>';
$htmlbody .=<<__EOM__;
<section><h2>Writing Newpage</h2>
<form action="./index.pl?cmd=newpost" method="post" name="editform" accept-charset="utf-8">
Title:<br />
<input type="text" name="title" placeholder="Newpage Name"><br />
Body:<br />
<textarea name="body" rows="20" cols="80" placeholder="Write!">
</textarea><br />
<button value="Post" name="bodysend" type="submit">Post</button>
</form>
</section>
__EOM__
} elsif ($query{'cmd'} eq 'newpost') {
	my ($title,$modified_date,$created_date,$tags,$autotags,$copyright,$body) = (&edit)[0,1,2,3,4,6,7];	
$title = 'undefined'.rand(16384) if $title eq '';
	&sql::do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body) values ('$title','$modified_date','$created_date','$tags','$autotags','$copyright','$body');",$data_source);

} elsif ($query{'cmd'} eq 'del') {
	my $token = &sha2(&date::spridate('%04d%02d%02d%02d%02d%02d').$ENV{'REMOTE_ADDR'});
	my $remote = &sha2($ENV{'REMOTE_ADDR'});

$htmlhead .= '<title>'.$pagename.' &gt; Delete@'.$conf_site.'</title>';
$htmlbody .=<<__EOM__;
<section><h2>Deleting $pagename</h2>
<p>Are you sure you want to delete $pagename?</p>
<form action="./index.pl?page=$pagenamens&amp;cmd=delpage&amp;gtoken=$token" method="post" name="confirmform" accept-charset="utf-8">
<input type="hidden" name="ptoken" value="$token">
<input type="hidden" name="remote" value="$remote">
<button value="Delete" name="confirmsend" type="submit">Yes, I want to DELETE</button>
</form>
</section>
__EOM__
} elsif ($query{'cmd'} eq 'delpage') {
	my $remote = &sha2($ENV{'REMOTE_ADDR'});
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = &cgidec::getline($postdata);
	if (((defined $form{'ptoken'}) and ($form{'ptoken'} eq $query{'gtoken'}) and ($form{'remote'} eq $remote))) {
		&sql::do("delete from pages where title='$pagename'",$data_source);
	}
} elsif ($query{'cmd'} eq 'search') {
	my $query = &security::textalize(&security::exorcism($query{'query'}));
	$query =~ s/\s/AND/g;
	my $pageslist = &listpages("select title from pages where body like '%$query%';","<a href=\"./index.pl?page=%s\">%s</a><br />");
$htmlhead .= '<title>Search &gt; Body@'.$conf_site.'</title>';
$htmlbody .=<<__EOM__;
<section>
<h2>Search results of '$query':</h2>
$pageslist
</section>
__EOM__
} elsif ($query{'cmd'} eq 'category') {
	my $query = &security::textalize(&security::exorcism($query{'query'}));
	$query =~ s/\s/AND/g;
	my $categorylist = &listcategory("select title from pages where tags like '%$query%';","<a href=\"./index.pl?page=%s\">%s</a><br />");
$htmlhead .= '<title>Search &gt; Category@'.$conf_site.'</title>';
$htmlbody .=<<__EOM__;
<section>
<h2>Pages related to '$query':</h2>
$categorylist
</section>
__EOM__
} elsif ($query{'cmd'} eq 'upload') {
$htmlhead .= '<title>'.$pagename. ' &gt; Upload@'.$conf_site.'</title>';
	$htmlbody .=<<__EOM__;
<section><h2>Upload to $pagename</h2>
<form action="./upload.pl" method="post" enctype='multipart/form-data'>
  <input type="file" name="file" /> <input type="hidden" name="backpage" value="$pagenamens"> <input type="submit" /> 
</form>
</section>
__EOM__
} elsif ($query{'cmd'} eq 'addfile') {
	my ($modifieddate,$file,$body);
	#$confer = &security::html(&security::exorcism($form{'body'}));
	$modifieddate = &date::spridate('%04d/%02d/%02d %02d:%02d:%02d');
	#$body =~ s/\n/<br \/>/g;
$htmlhead .= '<title>'.$pagename. ' &gt; UploadProcess@'.$conf_site.'</title>';
	my $filename = &security::html(&security::exorcism($query{'filename'}));
	my $original = &security::html(&security::exorcism($query{'orig'}));
	my @res = (&sql::fetch("select confer from pages where title='$pagename';",$data_source));

#$file = $res[0]."<a href=\"files/$filename\">$original</a> [<a href=\"remove.pl?file=$filename\">D</a>] | ";
$file = $res[0]."$filename/$original\t";

	&sql::do("update pages set lastmodified_date='$modifieddate', confer='$file' where title='$pagename';",$data_source);
} else {
	if (&sql::tableexists($data_source) == 0) {
		&sql::create_table($data_source);
		$htmlhead .= '<title>Miracle! Table was created!</title>';
		$htmlbody .= '<p>Table was created. Please reload.</p>';
	} else {
		require 'convert.pl';
		my @res = (&sql::fetch("select * from pages where title='TopPage';",$data_source));
		$htmlhead .= '<title>Top@'.$conf_site.'</title>';
		$htmlbody .= "<h2>Top</h2>".&convert::tohtml($res[7]);
		$htmlfoot .= "Last-modified: $res[1], Created: $res[2], Tags: $res[3], AutoTags: $res[4]<br />$res[6]<br />Cf.<br />$res[5]";
	}
}

if ($notable == 0) {
	my $categorylist = &listcategory("select tags from pages;","<dd><a href=\"./index.pl?cmd=category&amp;query=%s\">%s</a></dd>");
	my $pageslist = &listpages("select title from pages;","<dd><a href=\"./index.pl?page=%s\">%s</a></dd>");
#	my $pageslist = &listpages("select title from pages;","<dd><a href=\"./index.pl?page=","</dd>");
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
	#$confer = &security::html(&security::exorcism($form{'body'}));
	$body = &security::html(&security::exorcism($form{'body'}));
	$title = &security::textalize(&security::exorcism($form{'title'}));

	my $tagstr = $title;
#my $tags = $tagstr;
	$tagstr =~ s/^\[(.+)\](.+)/$1/g;
#warn $tagstr;
	#$tags =~ m/[\d\w-_]+/;
        #$tags =~ m/\[[~`!@#\$%^&\*=\+\{\}\\;:'"<>\?\/]+\]/;
	if (defined $2) {
		my @tagstrs= split(/\]\[/, $tagstr);
		foreach my $tag (@tagstrs) {
			$tag =~ s/[\[\]]+//g;
			$tags .= $tag.'|';
		}
	}
	$modified_date = &date::spridate('%04d/%02d/%02d %02d:%02d:%02d');
	$created_date = $modified_date;
	#$body =~ s/\n/<br \/>/g;
	return ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body);
}

sub listpages {
	my @res = (&sql::fetch($_[0],$data_source,0));
	my $pageslist;
	my $format = $_[1];
	foreach my $tmp (@res) {
		#$pageslist .= "$_[1]<a href=\"./index.pl?page=$tmp\">$tmp</a>$_[2]";
		my $formatmp = $format;
		#$tmp =~ tr/ /+/;
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
