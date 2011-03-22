package KSpade::SQL;

use strict;
use warnings;
use DBI;
use Digest::MD5  qw(md5_hex);

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
	return $self->fetch_ashash("select * from pages order by lastmodified_date desc limit $n;")
}

sub page_body {
	my $self = shift;
	my $title = shift;
	return ($self->fetch("select body from pages where title='$title';"));

	open FILE, getfilename($title);
}

sub page {
	my $self = shift;
	my $title = shift;

	my $fname = getfilename($title);
	if(-e $fname) {
		open FILE, $fname;
		my $body;
		read(FILE, $body, -1);
		close FILE;
		return $body;
	}
	return '';

	#return ($self->fetch("select * from pages where title='".$title."';"));
}

sub write_page {
	my $self = shift;
	my $page = shift;
	my $page_name = shift;

#	my $fname = getfilename($title);
#	if(open(FILE, $fname)) {
#		print FILE $body;
#		close FILE;
#		commit( $fname, $title);
#	} else {
#		warn 'cannot open the file' . $fname;
#	}

	return $self->do("update pages set title='$page-{'title'}', lastmodified_date='$page->{'date'}', tags='$page->{'tags'}',"."autotags='$page->{'autotags'}', copyright='$page->{'copyright'}', body='$page->{'body'}' where title='$page_name';");
}

sub page_exist {
	my $self = shift;
	my $title = shift;
	return ($self->fetch("select count(*) from pages where title='$title';"))[0] != 0;
	#return (-e getfilename($title));
}

sub delete_page {
	my $self = shift;
	my $name = shift;
	$self->do("delete from pages where title='$name';");

	unlink getfilename($name);
}

sub new_page {
	my $self = shift;
	my $page = shift;

	$self->do("insert into pages (title,lastmodified_date,created_date,tags,autotags,copyright,body)"
		."values('$page->{'title'}','$page->{'created_date'}','$page->{'created_date'}','$page->{'tags'}','$page->{'autotags'}','$page->{'copyright'}','ぬるぽ');");

	my $fname = getfilename($page->{'title'});
	open FILE, $fname;
	print FILE $page->{'body'};
	close FILE;
	commit( $fname, $page->{'title'});
}

# ページ名からファイル名を得るハッシュ関数
sub getfilename {
	my $title = shift;
	return "dat/page/".md5_hex($title);
}

sub commit {
	my $fname = shift;
	my $comment = shift;
	unless($comment) {
		$comment = $fname
	}
	#`cd dat/page; /usr/local/git/bin/git add $fname; /usr/local/git/bin/git commit -m '$comment'`;
	# TODO: error handling
	return 0;
}

sub DESTROY {
	my $self = shift;
	my $dbh = $self->{dbh};
	$dbh->disconnect if $dbh;
}

1;
