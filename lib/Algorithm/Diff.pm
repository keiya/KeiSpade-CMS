package Algorithm::Diff;
use strict;
use vars qw($VERSION @EXPORT_OK @ISA @EXPORT);
use integer;    # see below in _replaceNextLargerWith() for mod to make
                # if you don't use this
require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw(LCS diff traverse_sequences traverse_balanced sdiff);
$VERSION = sprintf('%d.%02d', (q$Revision: 1.15 $ =~ /\d+/g));

# McIlroy-Hunt diff algorithm
# Adapted from the Smalltalk code of Mario I. Wolczko, <mario@wolczko.com>
# by Ned Konz, perl@bike-nomad.com

=head1 NAME

Algorithm::Diff - Compute `intelligent' differences between two files / lists

=head1 SYNOPSIS

  use Algorithm::Diff qw(diff sdiff LCS traverse_sequences
                         traverse_balanced);

  @lcs    = LCS( \@seq1, \@seq2 );

  @lcs    = LCS( \@seq1, \@seq2, $key_generation_function );

  $lcsref = LCS( \@seq1, \@seq2 );

  $lcsref = LCS( \@seq1, \@seq2, $key_generation_function );

  @diffs = diff( \@seq1, \@seq2 );

  @diffs = diff( \@seq1, \@seq2, $key_generation_function );

  @sdiffs = sdiff( \@seq1, \@seq2 );

  @sdiffs = sdiff( \@seq1, \@seq2, $key_generation_function );

  traverse_sequences( \@seq1, \@seq2,
                     { MATCH => $callback,
                       DISCARD_A => $callback,
                       DISCARD_B => $callback,
                     } );

  traverse_sequences( \@seq1, \@seq2,
                     { MATCH => $callback,
                       DISCARD_A => $callback,
                       DISCARD_B => $callback,
                     },
                     $key_generation_function );

  traverse_balanced( \@seq1, \@seq2,
                     { MATCH => $callback,
                       DISCARD_A => $callback,
                       DISCARD_B => $callback,
                       CHANGE    => $callback,
                     } );

=head1 INTRODUCTION

(by Mark-Jason Dominus)

I once read an article written by the authors of C<diff>; they said
that they hard worked very hard on the algorithm until they found the
right one.

I think what they ended up using (and I hope someone will correct me,
because I am not very confident about this) was the `longest common
subsequence' method.  in the LCS problem, you have two sequences of
items:

        a b c d f g h j q z

        a b c d e f g i j k r x y z

and you want to find the longest sequence of items that is present in
both original sequences in the same order.  That is, you want to find
a new sequence I<S> which can be obtained from the first sequence by
deleting some items, and from the secend sequence by deleting other
items.  You also want I<S> to be as long as possible.  In this case
I<S> is

        a b c d f g j z

From there it's only a small step to get diff-like output:

        e   h i   k   q r x y
        +   - +   +   - + + +

This module solves the LCS problem.  It also includes a canned
function to generate C<diff>-like output.

It might seem from the example above that the LCS of two sequences is
always pretty obvious, but that's not always the case, especially when
the two sequences have many repeated elements.  For example, consider

	a x b y c z p d q
	a b c a x b y c z

A naive approach might start by matching up the C<a> and C<b> that
appear at the beginning of each sequence, like this:

	a x b y c         z p d q
	a   b   c a b y c z

This finds the common subsequence C<a b c z>.  But actually, the LCS
is C<a x b y c z>:

	      a x b y c z p d q
	a b c a x b y c z

=head1 USAGE

This module provides three exportable functions, which we'll deal with in
ascending order of difficulty: C<LCS>,
C<diff>, C<sdiff>, C<traverse_sequences>, and C<traverse_balanced>.

=head2 C<LCS>

Given references to two lists of items, LCS returns an array containing their
longest common subsequence.  In scalar context, it returns a reference to
such a list.

  @lcs    = LCS( \@seq1, \@seq2 );
  $lcsref = LCS( \@seq1, \@seq2 );

C<LCS> may be passed an optional third parameter; this is a CODE
reference to a key generation function.  See L</KEY GENERATION
FUNCTIONS>.

  @lcs    = LCS( \@seq1, \@seq2, $keyGen );
  $lcsref = LCS( \@seq1, \@seq2, $keyGen );

Additional parameters, if any, will be passed to the key generation
routine.

=head2 C<diff>

  @diffs     = diff( \@seq1, \@seq2 );
  $diffs_ref = diff( \@seq1, \@seq2 );

C<diff> computes the smallest set of additions and deletions necessary
to turn the first sequence into the second, and returns a description
of these changes.  The description is a list of I<hunks>; each hunk
represents a contiguous section of items which should be added,
deleted, or replaced.  The return value of C<diff> is a list of
hunks, or, in scalar context, a reference to such a list.

Here is an example:  The diff of the following two sequences:

  a b c e h j l m n p
  b c d e f j k l m r s t

Result:

 [
   [ [ '-', 0, 'a' ] ],

   [ [ '+', 2, 'd' ] ],

   [ [ '-', 4, 'h' ] ,
     [ '+', 4, 'f' ] ],

   [ [ '+', 6, 'k' ] ],

   [ [ '-', 8, 'n' ],
     [ '-', 9, 'p' ],
     [ '+', 9, 'r' ],
     [ '+', 10, 's' ],
     [ '+', 11, 't' ],
   ]
 ]

There are five hunks here.  The first hunk says that the C<a> at
position 0 of the first sequence should be deleted (C<->).  The second
hunk says that the C<d> at position 2 of the second sequence should
be inserted (C<+>).  The third hunk says that the C<h> at position 4
of the first sequence should be removed and replaced with the C<f>
from position 4 of the second sequence.  The other two hunks similarly.

C<diff> may be passed an optional third parameter; this is a CODE
reference to a key generation function.  See L</KEY GENERATION
FUNCTIONS>.

Additional parameters, if any, will be passed to the key generation
routine.

=head2 C<sdiff>

  @sdiffs     = sdiff( \@seq1, \@seq2 );
  $sdiffs_ref = sdiff( \@seq1, \@seq2 );

C<sdiff> computes all necessary components to show two sequences
and their minimized differences side by side, just like the
Unix-utility I<sdiff> does:

    same             same
    before     |     after
    old        <     -
    -          >     new

It returns a list of array refs, each pointing to an array of
display instructions. In scalar context it returns a reference
to such a list.

Display instructions consist of three elements: A modifier indicator
(C<+>: Element added, C<->: Element removed, C<u>: Element unmodified,
C<c>: Element changed) and the value of the old and new elements, to
be displayed side by side.

An C<sdiff> of the following two sequences:

  a b c e h j l m n p
  b c d e f j k l m r s t

results in

[ [ '-', 'a', ''  ],
  [ 'u', 'b', 'b' ],
  [ 'u', 'c', 'c' ],
  [ '+', '',  'd' ],
  [ 'u', 'e', 'e' ],
  [ 'c', 'h', 'f' ],
  [ 'u', 'j', 'j' ],
  [ '+', '',  'k' ],
  [ 'u', 'l', 'l' ],
  [ 'u', 'm', 'm' ],
  [ 'c', 'n', 'r' ],
  [ 'c', 'p', 's' ],
  [ '+', '', 't' ] ]

C<sdiff> may be passed an optional third parameter; this is a CODE
reference to a key generation function.  See L</KEY GENERATION
FUNCTIONS>.

Additional parameters, if any, will be passed to the key generation
routine.

=head2 C<traverse_sequences>

C<traverse_sequences> is the most general facility provided by this
module; C<diff> and C<LCS> are implemented as calls to it.

Imagine that there are two arrows.  Arrow A points to an element of sequence A,
and arrow B points to an element of the sequence B.  Initially, the arrows
point to the first elements of the respective sequences.  C<traverse_sequences>
will advance the arrows through the sequences one element at a time, calling an
appropriate user-specified callback function before each advance.  It
willadvance the arrows in such a way that if there are equal elements C<$A[$i]>
and C<$B[$j]> which are equal and which are part of the LCS, there will be
some moment during the execution of C<traverse_sequences> when arrow A is
pointing to C<$A[$i]> and arrow B is pointing to C<$B[$j]>.  When this happens,
C<traverse_sequences> will call the C<MATCH> callback function and then it will
advance both arrows.

Otherwise, one of the arrows is pointing to an element of its sequence that is
not part of the LCS.  C<traverse_sequences> will advance that arrow and will
call the C<DISCARD_A> or the C<DISCARD_B> callback, depending on which arrow it
advanced.  If both arrows point to elements that are not part of the LCS, then
C<traverse_sequences> will advance one of them and call the appropriate
callback, but it is not specified which it will call.

The arguments to C<traverse_sequences> are the two sequences to traverse, and a
hash which specifies the callback functions, like this:

  traverse_sequences( \@seq1, \@seq2,
                     { MATCH => $callback_1,
                       DISCARD_A => $callback_2,
                       DISCARD_B => $callback_3,
                     } );

Callbacks for MATCH, DISCARD_A, and DISCARD_B are invoked with at least the
indices of the two arrows as their arguments.  They are not expected to return
any values.  If a callback is omitted from the table, it is not called.

Callbacks for A_FINISHED and B_FINISHED are invoked with at least the
corresponding index in A or B.

If arrow A reaches the end of its sequence, before arrow B does,
C<traverse_sequences> will call the C<A_FINISHED> callback when it advances
arrow B, if there is such a function; if not it will call C<DISCARD_B> instead.
Similarly if arrow B finishes first.  C<traverse_sequences> returns when both
arrows are at the ends of their respective sequences.  It returns true on
success and false on failure.  At present there is no way to fail.

C<traverse_sequences> may be passed an optional fourth parameter; this is a
CODE reference to a key generation function.  See L</KEY GENERATION FUNCTIONS>.

Additional parameters, if any, will be passed to the key generation function.

=head2 C<traverse_balanced>

C<traverse_balanced> is an alternative to C<traverse_sequences>. It
uses a different algorithm to iterate through the entries in the
computed LCS. Instead of sticking to one side and showing element changes
as insertions and deletions only, it will jump back and forth between
the two sequences and report I<changes> occurring as deletions on one
side followed immediatly by an insertion on the other side.

In addition to the
C<DISCARD_A>,
C<DISCARD_B>, and
C<MATCH>
callbacks supported by C<traverse_sequences>, C<traverse_balanced> supports
a C<CHANGE> callback indicating that one element got C<replaced> by another:

  traverse_sequences( \@seq1, \@seq2,
                     { MATCH => $callback_1,
                       DISCARD_A => $callback_2,
                       DISCARD_B => $callback_3,
                       CHANGE    => $callback_4,
                     } );

If no C<CHANGE> callback is specified, C<traverse_balanced>
will map C<CHANGE> events to C<DISCARD_A> and C<DISCARD_B> actions,
therefore resulting in a similar behaviour as C<traverse_sequences>
with different order of events.

C<traverse_balanced> might be a bit slower than C<traverse_sequences>,
noticable only while processing huge amounts of data.

The C<sdiff> function of this module
is implemented as call to C<traverse_balanced>.

=head1 KEY GENERATION FUNCTIONS

C<diff>, C<LCS>, and C<traverse_sequences> accept an optional last parameter.
This is a CODE reference to a key generating (hashing) function that should
return a string that uniquely identifies a given element.  It should be the
case that if two elements are to be considered equal, their keys should be the
same (and the other way around).  If no key generation function is provided,
the key will be the element as a string.

By default, comparisons will use "eq" and elements will be turned into keys
using the default stringizing operator '""'.

Where this is important is when you're comparing something other than strings.
If it is the case that you have multiple different objects that should be
considered to be equal, you should supply a key generation function. Otherwise,
you have to make sure that your arrays contain unique references.

For instance, consider this example:

  package Person;

  sub new
  {
    my $package = shift;
    return bless { name => '', ssn => '', @_ }, $package;
  }

  sub clone
  {
    my $old = shift;
    my $new = bless { %$old }, ref($old);
  }

  sub hash
  {
    return shift()->{'ssn'};
  }

  my $person1 = Person->new( name => 'Joe', ssn => '123-45-6789' );
  my $person2 = Person->new( name => 'Mary', ssn => '123-47-0000' );
  my $person3 = Person->new( name => 'Pete', ssn => '999-45-2222' );
  my $person4 = Person->new( name => 'Peggy', ssn => '123-45-9999' );
  my $person5 = Person->new( name => 'Frank', ssn => '000-45-9999' );

If you did this:

  my $array1 = [ $person1, $person2, $person4 ];
  my $array2 = [ $person1, $person3, $person4, $person5 ];
  Algorithm::Diff::diff( $array1, $array2 );

everything would work out OK (each of the objects would be converted
into a string like "Person=HASH(0x82425b0)" for comparison).

But if you did this:

  my $array1 = [ $person1, $person2, $person4 ];
  my $array2 = [ $person1, $person3, $person4->clone(), $person5 ];
  Algorithm::Diff::diff( $array1, $array2 );

$person4 and $person4->clone() (which have the same name and SSN)
would be seen as different objects. If you wanted them to be considered
equivalent, you would have to pass in a key generation function:

  my $array1 = [ $person1, $person2, $person4 ];
  my $array2 = [ $person1, $person3, $person4->clone(), $person5 ];
  Algorithm::Diff::diff( $array1, $array2, \&Person::hash );

This would use the 'ssn' field in each Person as a comparison key, and
so would consider $person4 and $person4->clone() as equal.

You may also pass additional parameters to the key generation function
if you wish.

=head1 AUTHOR

This version by Ned Konz, perl@bike-nomad.com

=head1 LICENSE

Copyright (c) 2000-2002 Ned Konz.  All rights reserved.
This program is free software;
you can redistribute it and/or modify it under the same terms
as Perl itself.

=head1 CREDITS

Versions through 0.59 (and much of this documentation) were written by:

Mark-Jason Dominus, mjd-perl-diff@plover.com

This version borrows the documentation and names of the routines
from Mark-Jason's, but has all new code in Diff.pm.

This code was adapted from the Smalltalk code of
Mario Wolczko <mario@wolczko.com>, which is available at
ftp://st.cs.uiuc.edu/pub/Smalltalk/MANCHESTER/manchester/4.0/diff.st

C<sdiff> and C<traverse_balanced> were written by Mike Schilli
<m@perlmeister.com>.

The algorithm is that described in
I<A Fast Algorithm for Computing Longest Common Subsequences>,
CACM, vol.20, no.5, pp.350-353, May 1977, with a few
minor improvements to improve the speed.

=cut

# Create a hash that maps each element of $aCollection to the set of positions
# it occupies in $aCollection, restricted to the elements within the range of
# indexes specified by $start and $end.
# The fourth parameter is a subroutine reference that will be called to
# generate a string to use as a key.
# Additional parameters, if any, will be passed to this subroutine.
#
# my $hashRef = _withPositionsOfInInterval( \@array, $start, $end, $keyGen );

sub _withPositionsOfInInterval
{
	my $aCollection = shift;    # array ref
	my $start       = shift;
	my $end         = shift;
	my $keyGen      = shift;
	my %d;
	my $index;
	for ( $index = $start ; $index <= $end ; $index++ )
	{
		my $element = $aCollection->[$index];
		my $key = &$keyGen( $element, @_ );
		if ( exists( $d{$key} ) )
		{
			unshift ( @{ $d{$key} }, $index );
		}
		else
		{
			$d{$key} = [$index];
		}
	}
	return wantarray ? %d : \%d;
}

# Find the place at which aValue would normally be inserted into the array. If
# that place is already occupied by aValue, do nothing, and return undef. If
# the place does not exist (i.e., it is off the end of the array), add it to
# the end, otherwise replace the element at that point with aValue.
# It is assumed that the array's values are numeric.
# This is where the bulk (75%) of the time is spent in this module, so try to
# make it fast!

sub _replaceNextLargerWith
{
	my ( $array, $aValue, $high ) = @_;
	$high ||= $#$array;

	# off the end?
	if ( $high == -1 || $aValue > $array->[-1] )
	{
		push ( @$array, $aValue );
		return $high + 1;
	}

	# binary search for insertion point...
	my $low = 0;
	my $index;
	my $found;
	while ( $low <= $high )
	{
		$index = ( $high + $low ) / 2;

		#		$index = int(( $high + $low ) / 2);		# without 'use integer'
		$found = $array->[$index];

		if ( $aValue == $found )
		{
			return undef;
		}
		elsif ( $aValue > $found )
		{
			$low = $index + 1;
		}
		else
		{
			$high = $index - 1;
		}
	}

	# now insertion point is in $low.
	$array->[$low] = $aValue;    # overwrite next larger
	return $low;
}

# This method computes the longest common subsequence in $a and $b.

# Result is array or ref, whose contents is such that
# 	$a->[ $i ] == $b->[ $result[ $i ] ]
# foreach $i in ( 0 .. $#result ) if $result[ $i ] is defined.

# An additional argument may be passed; this is a hash or key generating
# function that should return a string that uniquely identifies the given
# element.  It should be the case that if the key is the same, the elements
# will compare the same. If this parameter is undef or missing, the key
# will be the element as a string.

# By default, comparisons will use "eq" and elements will be turned into keys
# using the default stringizing operator '""'.

# Additional parameters, if any, will be passed to the key generation routine.

sub _longestCommonSubsequence
{
	my $a      = shift;    # array ref
	my $b      = shift;    # array ref
	my $keyGen = shift;    # code ref
	my $compare;           # code ref

	# set up code refs
	# Note that these are optimized.
	if ( !defined($keyGen) )    # optimize for strings
	{
		$keyGen = sub { $_[0] };
		$compare = sub { my ( $a, $b ) = @_; $a eq $b };
	}
	else
	{
		$compare = sub {
			my $a = shift;
			my $b = shift;
			&$keyGen( $a, @_ ) eq &$keyGen( $b, @_ );
		};
	}

	my ( $aStart, $aFinish, $bStart, $bFinish, $matchVector ) =
	  ( 0, $#$a, 0, $#$b, [] );

	# First we prune off any common elements at the beginning
	while ( $aStart <= $aFinish
		and $bStart <= $bFinish
		and &$compare( $a->[$aStart], $b->[$bStart], @_ ) )
	{
		$matchVector->[ $aStart++ ] = $bStart++;
	}

	# now the end
	while ( $aStart <= $aFinish
		and $bStart <= $bFinish
		and &$compare( $a->[$aFinish], $b->[$bFinish], @_ ) )
	{
		$matchVector->[ $aFinish-- ] = $bFinish--;
	}

	# Now compute the equivalence classes of positions of elements
	my $bMatches =
	  _withPositionsOfInInterval( $b, $bStart, $bFinish, $keyGen, @_ );
	my $thresh = [];
	my $links  = [];

	my ( $i, $ai, $j, $k );
	for ( $i = $aStart ; $i <= $aFinish ; $i++ )
	{
		$ai = &$keyGen( $a->[$i], @_ );
		if ( exists( $bMatches->{$ai} ) )
		{
			$k = 0;
			for $j ( @{ $bMatches->{$ai} } )
			{

				# optimization: most of the time this will be true
				if ( $k and $thresh->[$k] > $j and $thresh->[ $k - 1 ] < $j )
				{
					$thresh->[$k] = $j;
				}
				else
				{
					$k = _replaceNextLargerWith( $thresh, $j, $k );
				}

				# oddly, it's faster to always test this (CPU cache?).
				if ( defined($k) )
				{
					$links->[$k] =
					  [ ( $k ? $links->[ $k - 1 ] : undef ), $i, $j ];
				}
			}
		}
	}

	if (@$thresh)
	{
		for ( my $link = $links->[$#$thresh] ; $link ; $link = $link->[0] )
		{
			$matchVector->[ $link->[1] ] = $link->[2];
		}
	}

	return wantarray ? @$matchVector : $matchVector;
}

sub traverse_sequences
{
	my $a                 = shift;                                  # array ref
	my $b                 = shift;                                  # array ref
	my $callbacks         = shift || {};
	my $keyGen            = shift;
	my $matchCallback     = $callbacks->{'MATCH'} || sub { };
	my $discardACallback  = $callbacks->{'DISCARD_A'} || sub { };
	my $finishedACallback = $callbacks->{'A_FINISHED'};
	my $discardBCallback  = $callbacks->{'DISCARD_B'} || sub { };
	my $finishedBCallback = $callbacks->{'B_FINISHED'};
	my $matchVector = _longestCommonSubsequence( $a, $b, $keyGen, @_ );

	# Process all the lines in @$matchVector
	my $lastA = $#$a;
	my $lastB = $#$b;
	my $bi    = 0;
	my $ai;

	for ( $ai = 0 ; $ai <= $#$matchVector ; $ai++ )
	{
		my $bLine = $matchVector->[$ai];
		if ( defined($bLine) )    # matched
		{
			&$discardBCallback( $ai, $bi++, @_ ) while $bi < $bLine;
			&$matchCallback( $ai,    $bi++, @_ );
		}
		else
		{
			&$discardACallback( $ai, $bi, @_ );
		}
	}

	# The last entry (if any) processed was a match.
	# $ai and $bi point just past the last matching lines in their sequences.

	while ( $ai <= $lastA or $bi <= $lastB )
	{

		# last A?
		if ( $ai == $lastA + 1 and $bi <= $lastB )
		{
			if ( defined($finishedACallback) )
			{
				&$finishedACallback( $lastA, @_ );
				$finishedACallback = undef;
			}
			else
			{
				&$discardBCallback( $ai, $bi++, @_ ) while $bi <= $lastB;
			}
		}

		# last B?
		if ( $bi == $lastB + 1 and $ai <= $lastA )
		{
			if ( defined($finishedBCallback) )
			{
				&$finishedBCallback( $lastB, @_ );
				$finishedBCallback = undef;
			}
			else
			{
				&$discardACallback( $ai++, $bi, @_ ) while $ai <= $lastA;
			}
		}

		&$discardACallback( $ai++, $bi, @_ ) if $ai <= $lastA;
		&$discardBCallback( $ai, $bi++, @_ ) if $bi <= $lastB;
	}

	return 1;
}

sub traverse_balanced
{
	my $a                 = shift;                                  # array ref
	my $b                 = shift;                                  # array ref
	my $callbacks         = shift || {};
	my $keyGen            = shift;
	my $matchCallback     = $callbacks->{'MATCH'} || sub { };
	my $discardACallback  = $callbacks->{'DISCARD_A'} || sub { };
	my $discardBCallback  = $callbacks->{'DISCARD_B'} || sub { };
	my $changeCallback    = $callbacks->{'CHANGE'};
	my $matchVector = _longestCommonSubsequence( $a, $b, $keyGen, @_ );

	# Process all the lines in match vector
	my $lastA = $#$a;
	my $lastB = $#$b;
	my $bi    = 0;
	my $ai    = 0;
	my $ma    = -1;
	my $mb;

	while (1)
	{

		# Find next match indices $ma and $mb
		do { $ma++ } while ( $ma <= $#$matchVector && !defined $matchVector->[$ma] );

		last if $ma > $#$matchVector;    # end of matchVector?
		$mb = $matchVector->[$ma];

		# Proceed with discard a/b or change events until
		# next match
		while ( $ai < $ma || $bi < $mb )
		{

			if ( $ai < $ma && $bi < $mb )
			{

				# Change
				if ( defined $changeCallback )
				{
					&$changeCallback( $ai++, $bi++, @_ );
				}
				else
				{
					&$discardACallback( $ai++, $bi, @_ );
					&$discardBCallback( $ai, $bi++, @_ );
				}
			}
			elsif ( $ai < $ma )
			{
				&$discardACallback( $ai++, $bi, @_ );
			}
			else
			{

				# $bi < $mb
				&$discardBCallback( $ai, $bi++, @_ );
			}
		}

		# Match
		&$matchCallback( $ai++, $bi++, @_ );
	}

	while ( $ai <= $lastA || $bi <= $lastB )
	{
		if ( $ai <= $lastA && $bi <= $lastB )
		{

			# Change
			if ( defined $changeCallback )
			{
				&$changeCallback( $ai++, $bi++, @_ );
			}
			else
			{
				&$discardACallback( $ai++, $bi, @_ );
				&$discardBCallback( $ai, $bi++, @_ );
			}
		}
		elsif ( $ai <= $lastA )
		{
			&$discardACallback( $ai++, $bi, @_ );
		}
		else
		{

			# $bi <= $lastB
			&$discardBCallback( $ai, $bi++, @_ );
		}
	}

	return 1;
}

sub LCS
{
	my $a = shift;                                           # array ref
	my $matchVector = _longestCommonSubsequence( $a, @_ );
	my @retval;
	my $i;
	for ( $i = 0 ; $i <= $#$matchVector ; $i++ )
	{
		if ( defined( $matchVector->[$i] ) )
		{
			push ( @retval, $a->[$i] );
		}
	}
	return wantarray ? @retval : \@retval;
}

sub diff
{
	my $a      = shift;    # array ref
	my $b      = shift;    # array ref
	my $retval = [];
	my $hunk   = [];
	my $discard = sub { push ( @$hunk, [ '-', $_[0], $a->[ $_[0] ] ] ) };
	my $add = sub { push ( @$hunk, [ '+', $_[1], $b->[ $_[1] ] ] ) };
	my $match = sub { push ( @$retval, $hunk ) if scalar(@$hunk); $hunk = [] };
	traverse_sequences( $a, $b,
		{ MATCH => $match, DISCARD_A => $discard, DISCARD_B => $add }, @_ );
	&$match();
	return wantarray ? @$retval : $retval;
}

sub sdiff
{
	my $a      = shift;    # array ref
	my $b      = shift;    # array ref
	my $retval = [];
	my $discard = sub { push ( @$retval, [ '-', $a->[ $_[0] ], "" ] ) };
	my $add = sub { push ( @$retval, [ '+', "", $b->[ $_[1] ] ] ) };
	my $change = sub {
		push ( @$retval, [ 'c', $a->[ $_[0] ], $b->[ $_[1] ] ] );
	};
	my $match = sub {
		push ( @$retval, [ 'u', $a->[ $_[0] ], $b->[ $_[1] ] ] );
	};
	traverse_balanced(
		$a,
		$b,
		{
			MATCH     => $match,
			DISCARD_A => $discard,
			DISCARD_B => $add,
			CHANGE    => $change,
		},
		@_
	);
	return wantarray ? @$retval : $retval;
}

1;
