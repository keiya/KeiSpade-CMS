#!/usr/bin/perl
package KSpade::Lock;

use constant LOCKDIR => 'lock';
sub new {
	my $class = shift;
	while (!mkdir(LOCKDIR, 0755)) {
		print "retry\n";
		sleep 1;
	}
	return bless {}, $class
}
sub DESTROY {
	my $self = shift;
	rmdir LOCKDIR;
}

package KSpade::Pagelist;
use warnings;
use strict;
use XML::Simple;

sub new {
	my $class = shift;
	my $fname = shift;
	my $self = {fname => $fname};
	$self->{lock} = KSpade::Lock->new();
	bless $self, $class;

	$self->readxml();

	return $self;
}

# ex) $toppage = $self->search( sub{ $_->{'title'} = 'TopPage'} );
sub search {
	my $self = shift;
	my $func = shift;
	my @ret;
	foreach (@{$self->{xml}->{pagelist}[0]->{page}}) {
		if (&$func($_)) {
			push @ret, $_;
		}
	}
	return @ret;
}

sub getpage_by_pageid {
	my ($self, $pageid) = @_;
	return ($self->search(sub { $_->{pageid}[0] eq $pageid }))[0];
}

sub getpage_by_title {
	my $self = shift;
	my $title = shift;
	return ($self->search(sub { $_->{title}[0] eq $title }))[0];
}

sub addpage {
	my ($self, $page) = @_;
	push @{$self->{xml}->{pagelist}[0]->{page}}, $page;
}

# save as xml
sub savexml {
	my $self = shift;

	$self->{xml} = XML::Simple->new()->XMLout( $self->{xml},
		OutputFile => $self->{fname}, XMLDecl => "<?xml version='1.0'?>",
		RootName => 'page', KeepRoot => 1);
}

# read xml file
sub readxml {
	my $self = shift;

	if (-e $self->{fname}) {
		$self->{xml} = XML::Simple->new()->XMLin( $self->{fname}, KeepRoot => 1, ForceArray => 1);
	} else {
		warn "file done not exist $self->{fname}";
	}
}

sub DESTROY {
}

1;
