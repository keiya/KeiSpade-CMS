package SQL;

sub new {
	my ($class,$datasource) = @_;
	my $dbh = DBI->connect($datasource);
	my $self = {dbh=>$dbh};
	return bless $self, $class;
}

sub fetch {
	my ($self, $statement) = @_;
	my $dbh = $self->{dbh};
	my $sth = $dbh->prepare($statement);
	my $rv = $sth->execute;
	my @row;
#	print "SQL COMMAND: [$_[0]] from table '$_[1]'<br />";
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
	#my $arr_ref = $th->fetchrow_arrayref;
	#@row = @$arr_ref; 
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
       	$notable = 1;
       	my $create_table = "create table pages (" .
       	                       "title," .
       	                       "lastmodified_date," .
       	                       "created_date," .
       	                       "tags," .
       	                       "autotags," .
       	                       "confer," .
       	                       "copyright," .
                              "body" .
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

sub DESTROY {
	my $self = shift;
	my $dbh = $self->{dbh};
	$dbh->disconnect;
}

1;
