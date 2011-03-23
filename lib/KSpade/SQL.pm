package KSpade::SQL;

use strict;
use warnings;
use DBI;
use Digest::Perl::MD5 'md5_hex';

sub new {
	my ($class,$datasource) = @_;
	my $dbh = DBI->connect($datasource);
	my $self = {dbh=>$dbh};
	return bless $self, $class;
}

sub fetch_ashash {
	my ($self, $statement, $key) = @_;
	$key = 1 unless defined $key;
	my $dbh = $self->{dbh};
	my $arr_ref = $dbh->selectall_hashref($statement,$key);
	return $arr_ref;
}

sub fetch {
	my ($self, $statement) = @_;
	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare($statement);
	my $rv = $sth->execute;
	my @row;
	my $i = 0;
	while ( my $arr_ref = $sth->fetchrow_arrayref ){
		if (defined $_[2]) {
			push(@row, (@$arr_ref)[$_[2]]);
		} else {
			@row = @$arr_ref; 
		}
	} continue {
			$i++;
	}
	$sth->finish;
	return(@row);
}

sub do {
	my ($self, $statement, $datasource) = @_;
	my $dbh = $self->{dbh};
	$dbh->do($statement);
	return 1;
}

sub create_table {
	my ($self, $recdata) = @_;
	my $dbh = $self->{dbh};
	#my $notable = 1;
       	my $create_table = "create table pages (" .
       	                       "title," .
       	                       "lastmodified_date," .
       	                       "created_date," .
       	                       "tags," .
       	                       "autotags," .
       	                       "confer," .
       	                       "copyright," .
                               "body," .
	                           "author" .
       	                   ");";
       	$dbh->do($create_table);
}

sub tableexists {
	my ($self) = @_;
	my $dbh = $self->{dbh};
	# なかったらテーブルつくる
	my @res = $self->fetch("select count(*) from sqlite_master where type='table' and name='pages';");
	return $res[0];
}

sub recently_modified_pages {
	my $self = shift;
	my $n = shift;
	return ($self->fetch("select lastmodified_date from pages order by lastmodified_date desc limit $n"))[0];
}
sub recently_modified_pages_as_hash {
	my $self = shift;
	my $n = shift;
	return ($self->fetch_ashash("select * from pages order by lastmodified_date desc limit $n;"))[0];
}

sub page_body {
	my $self = shift;
	my $title = shift;

	my $dir = "dat/page";
	my $fname = getfilename($title);
	if(-e "$dir/$fname") {
		my $as_scalar = `cat $dir/$fname`;
		return $as_scalar;
	}
	warn "File does not exist $fname";
	return "File does not exist $fname";
}

sub page_ashash {
	my $self = shift;
	my $title = shift;
	my $res = $self->fetch_ashash("select * from pages where title='$title';")->{$title};
	$res->{'body'} = $self->page_body($title);
	return $res;
}

sub write_page {
	my $self = shift;
	my ($title, $date, $tags, $autotags, $copyright, $body, $page_name) = @_;
	$self->do("update pages set title='$title', lastmodified_date='$date', tags='$tags',"."autotags='$autotags', copyright='$copyright', body='ぷよぷよフィーバー' where title='".$page_name."';");
	write_pagefile({'title' => $title, 'body' => $body});
}

sub page_exist {
	my $self = shift;
	my $title = shift;
	my $dir = 'dat/page';
	my $fname = getfilename($title);
	return -e "$dir/$fname";
}

sub delete_page {
	my $self = shift;
	my $title = shift;
	my $dir = 'dat/page';
	my $fname = getfilename($title);
	unlink "$dir/$fname";
	$self->do("delete from pages where title='$title';");
	
	gitcommit($dir, $fname, "delete page $title");
}

sub new_page {
	my $self = shift;
	my $page = shift;

	$self->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)"
		."values('$page->{'title'}','$page->{'created_date'}','$page->{'created_date'}','$page->{'tags'}','$page->{'autotags'}','$page->{'copyright'}','ぷよぷよフィーバー');");
	write_pagefile($page);
}

sub write_pagefile {
	my $page = shift;
	my $dir = 'dat/page';
	my $fname = getfilename($page->{'title'});
	if(open(FILE, ">$dir/$fname")) {
		print FILE $page->{'body'};
		close FILE;

		gitcommit($dir, $fname, $page->{'title'});
	} else {
		warn $!;
	}
}

sub gitcommit {
	my $dir = shift;
	my $fname = shift;
	my $comment = shift;

	$comment = $fname unless $comment;
	`cd $dir;git add $fname;git commit $fname -m '$comment';cd ../..`;
}

sub getfilename {
	my $title = shift;
	return md5_hex($title);
}

sub DESTROY {
	my $self = shift;
	my $dbh = $self->{dbh};
	$dbh->disconnect if $dbh;
}

1;
