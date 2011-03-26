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
	my $arg  = shift;
	my @ret;
	foreach (@{$self->{xml}->{pagelist}[0]->{page}}) {
		if (&$func($_, $arg)) {
			push @ret, $_;
		}
	}
	return \@ret;
}

sub getpage_by_pageid {
	my ($self, $pageid) = @_;
	return ($self->search(sub { $_->{pageid} eq $pageid }))->[0];
}

sub getpage_by_title {
	my $self = shift;
	my $title = shift;
	return ($self->search(sub { $_->{title} eq $title }))->[0];
}

sub is_ignore_key {
	my $key = shift;
	my @ignore_key = ('body', 'bodyhash');
	foreach (@ignore_key) {
		return 1 if $key eq $_;
	}
	return 0;
}

sub addpage {
	my ($self, $page) = @_;
	my %hash = %$page;
	foreach (keys %hash) {
		delete $hash{$_} if is_ignore_key($_);
	}
	push @{$self->{xml}->{pagelist}[0]->{page}}, \%hash;
}

sub updatepage {
	my ($self, $page) = @_;
	my $ref = $self->getpage_by_pageid($page->{pageid});
	foreach (keys %$page) {
		next if is_ignore_key($_);
		$ref->{$_} = $page->{$_};
	}
}

sub delpage {
	my ($self, $pageid) = @_;
	my $size = @{$self->{xml}->{pagelist}[0]->{page}};
	for (my $i = 0; $i < $size; $i++) {
		if ($self->{xml}->{pagelist}[0]->{page}[$i]->{pageid} eq $pageid) {
			splice @{$self->{xml}->{pagelist}[0]->{page}}, $i, 1;
			last;
		}
	}
}

# save as xml
sub savexml {
	my $self = shift;

	XML::Simple->new()->XMLout( $self->{xml},
		OutputFile => $self->{fname}, XMLDecl => "<?xml version='1.0'?>",
		RootName => 'page', KeepRoot => 1);
}

# read xml file
sub readxml {
	my $self = shift;

	if (-e $self->{fname}) {
		$self->{xml} = XML::Simple->new()->XMLin( $self->{fname}, KeepRoot => 1, ForceArray => 1);
	} else {
		$self->{xml} = { pagelist => [{}] };
	}
}

sub DESTROY {
}

1;
