#!/usr/bin/perl

# KeiSpade Uploader
# KeiSpade Developping Team
# upl.pl 0.4.1

package KSpade::Addon::upl;

use strict;
use warnings;
use lib '../lib';
use KSpade;

sub new {
	$main::vars{'Addons::upl::UploaderName'} = 'addons/upl/upload.cgi';
}

sub upload {
	# print upload form
	$main::vars{'HtmlHead'} .= '<title>'.$main::vars{'PageName'}. ' &gt; Upload@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/upload.html',\%main::vars);

	KSpade::Show::html('html/frmwrk.html',\%main::vars);
} 
sub delupload {
# print delete confirm
	my $filename = KSpade::Security::htmlexor($main::query{'filename'});
	$main::vars{'DeleteFileName'} = $filename;
	#$main::vars{'PagesList'} = &listpages("select title from pages where confer like '%$filename%';");
	my @pages = $main::sql->fetch("select title from pages where confer like '%$filename%';");
	$main::vars{'PagesList'} = KSpade::Show::pageslist("select title from pages where confer like '%$filename%';"
		,"<a href=\"./$main::vars{'ScriptName'}?page=%s\">%s</a><br />");
	$main::vars{'HtmlHead'} .= '<title>'.$filename. ' &gt; Delete Uploaded Files@'.$main::vars{'SiteName'}.'</title>';
	$main::vars{'HtmlBody'} .= KSpade::Show::template('html/delupload.html',\%main::vars);
	KSpade::Show::html('html/frmwrk.html',\%main::vars);
}

sub delfile {
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	my $filename = KSpade::Security::htmlexor($main::query{'filename'});
	my @pages = $main::sql->fetch("select title from pages where confer like '%$filename%';",0);
	foreach my $tmp (@pages) {
		my @files = $main::sql->fetch("select confer from pages where title='$tmp';");
		$files[0] =~ s/\[$filename\/.+?\]//g;
		unlink('./dat/page/files/'.$filename);
		my $modifieddate = time();
		$main::sql->do("update pages set lastmodified_date='$modifieddate', confer='$files[0]' where title='$tmp';");
	}
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
	my @res = ($main::sql->fetch("select confer from pages where title='$main::vars{'PageName'}';"));
	my $files = $res[0];
	if ($files =~ /$filename/) {

	} else {
		my $tmp  = KSpade::DateTime::spridate('%04d %2d %2d %2d:%02d:%02d');
		$files .= "[$filename/$original($tmp)]";
		$main::sql->do("update pages set lastmodified_date='$page{'modified_date'}', confer='$files' where title='$main::vars{'PageName'}';");
	}
	
print "Content-Type: text/html; charset=UTF-8\n\n";
	#KSpade::Show::html('../html/frmwrk.html',\%main::vars);
}

1;
