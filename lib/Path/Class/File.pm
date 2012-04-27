package Path::Class::File;

$VERSION = '0.21';

use strict;
use Path::Class::Dir;
use base qw(Path::Class::Entity);
use Carp;

use IO::File ();

sub new {
  my $self = shift->SUPER::new;
  my $file = pop();
  my @dirs = @_;

  my ($volume, $dirs, $base) = $self->_spec->splitpath($file);

  if (length $dirs) {
    push @dirs, $self->_spec->catpath($volume, $dirs, '');
  }

  $self->{dir}  = @dirs ? $self->dir_class->new(@dirs) : undef;
  $self->{file} = $base;

  return $self;
}

sub dir_class { "Path::Class::Dir" }

sub as_foreign {
  my ($self, $type) = @_;
  local $Path::Class::Foreign = $self->_spec_class($type);
  my $foreign = ref($self)->SUPER::new;
  $foreign->{dir} = $self->{dir}->as_foreign($type) if defined $self->{dir};
  $foreign->{file} = $self->{file};
  return $foreign;
}

sub stringify {
  my $self = shift;
  return $self->{file} unless defined $self->{dir};
  return $self->_spec->catfile($self->{dir}->stringify, $self->{file});
}

sub dir {
  my $self = shift;
  return $self->{dir} if defined $self->{dir};
  return $self->dir_class->new($self->_spec->curdir);
}
BEGIN { *parent = \&dir; }

sub volume {
  my $self = shift;
  return '' unless defined $self->{dir};
  return $self->{dir}->volume;
}

sub basename { shift->{file} }
sub open  { IO::File->new(@_) }

sub openr { $_[0]->open('r') or croak "Can't read $_[0]: $!"  }
sub openw { $_[0]->open('w') or croak "Can't write $_[0]: $!" }

sub touch {
  my $self = shift;
  if (-e $self) {
    my $now = time();
    utime $now, $now, $self;
  } else {
    $self->openw;
  }
}

sub slurp {
  my ($self, %args) = @_;
  my $iomode = $args{iomode} || 'r';
  my $fh = $self->open($iomode) or croak "Can't read $self: $!";

  if ($args{chomped} or $args{chomp}) {
    chomp( my @data = <$fh> );
    return wantarray ? @data : join '', @data;
  }

  local $/ unless wantarray;
  return <$fh>;
}

sub remove {
  my $file = shift->stringify;
  return unlink $file unless -e $file; # Sets $! correctly
  1 while unlink $file;
  return not -e $file;
}

1;
__END__

=head1 NAME

Path::Class::File - Objects representing files

=head1 SYNOPSIS

  use Path::Class qw(file);  # Export a short constructor

  my $file = file('foo', 'bar.txt');  # Path::Class::File object
  my $file = Path::Class::File->new('foo', 'bar.txt'); # Same thing

  # Stringifies to 'foo/bar.txt' on Unix, 'foo\bar.txt' on Windows, etc.
  print "file: $file\n";

  if ($file->is_absolute) { ... }
  if ($file->is_relative) { ... }

  my $v = $file->volume; # Could be 'C:' on Windows, empty string
                         # on Unix, 'Macintosh HD:' on Mac OS

  $file->cleanup; # Perform logical cleanup of pathname
  $file->resolve; # Perform physical cleanup of pathname

  my $dir = $file->dir;  # A Path::Class::Dir object

  my $abs = $file->absolute; # Transform to absolute path
  my $rel = $file->relative; # Transform to relative path

=head1 DESCRIPTION

The C<Path::Class::File> class contains functionality for manipulating
file names in a cross-platform way.

=head1 METHODS

=over 4

=item $file = Path::Class::File->new( <dir1>, <dir2>, ..., <file> )

=item $file = file( <dir1>, <dir2>, ..., <file> )

Creates a new C<Path::Class::File> object and returns it.  The
arguments specify the path to the file.  Any volume may also be
specified as the first argument, or as part of the first argument.
You can use platform-neutral syntax:

  my $dir = file( 'foo', 'bar', 'baz.txt' );

or platform-native syntax:

  my $dir = dir( 'foo/bar/baz.txt' );

or a mixture of the two:

  my $dir = dir( 'foo/bar', 'baz.txt' );

All three of the above examples create relative paths.  To create an
absolute path, either use the platform native syntax for doing so:

  my $dir = dir( '/var/tmp/foo.txt' );

or use an empty string as the first argument:

  my $dir = dir( '', 'var', 'tmp', 'foo.txt' );

If the second form seems awkward, that's somewhat intentional - paths
like C</var/tmp> or C<\Windows> aren't cross-platform concepts in the
first place, so they probably shouldn't appear in your code if you're
trying to be cross-platform.  The first form is perfectly fine,
because paths like this may come from config files, user input, or
whatever.

=item $file->stringify

This method is called internally when a C<Path::Class::File> object is
used in a string context, so the following are equivalent:

  $string = $file->stringify;
  $string = "$file";

=item $file->volume

Returns the volume (e.g. C<C:> on Windows, C<Macintosh HD:> on Mac OS,
etc.) of the object, if any.  Otherwise, returns the empty string.

=item $file->basename

Returns the name of the file as a string, without the directory
portion (if any).

=item $file->is_dir

Returns a boolean value indicating whether this object represents a
directory.  Not surprisingly, C<Path::Class::File> objects always
return false, and C<Path::Class::Dir> objects always return true.

=item $file->is_absolute

Returns true or false depending on whether the file refers to an
absolute path specifier (like C</usr/local/foo.txt> or C<\Windows\Foo.txt>).

=item $file->is_relative

Returns true or false depending on whether the file refers to a
relative path specifier (like C<lib/foo.txt> or C<.\Foo.txt>).

=item $file->cleanup

Performs a logical cleanup of the file path.  For instance:

  my $file = file('/foo//baz/./foo.txt')->cleanup;
  # $file now represents '/foo/baz/foo.txt';

=item $dir->resolve

Performs a physical cleanup of the file path.  For instance:

  my $dir = dir('/foo/baz/../foo.txt')->resolve;
  # $dir now represents '/foo/foo.txt', assuming no symlinks

This actually consults the filesystem to verify the validity of the
path.

=item $dir = $file->dir

Returns a C<Path::Class::Dir> object representing the directory
containing this file.

=item $dir = $file->parent

A synonym for the C<dir()> method.

=item $abs = $file->absolute

Returns a C<Path::Class::File> object representing C<$file> as an
absolute path.  An optional argument, given as either a string or a
C<Path::Class::Dir> object, specifies the directory to use as the base
of relativity - otherwise the current working directory will be used.

=item $rel = $file->relative

Returns a C<Path::Class::File> object representing C<$file> as a
relative path.  An optional argument, given as either a string or a
C<Path::Class::Dir> object, specifies the directory to use as the base
of relativity - otherwise the current working directory will be used.

=item $foreign = $file->as_foreign($type)

Returns a C<Path::Class::File> object representing C<$file> as it would
be specified on a system of type C<$type>.  Known types include
C<Unix>, C<Win32>, C<Mac>, C<VMS>, and C<OS2>, i.e. anything for which
there is a subclass of C<File::Spec>.

Any generated objects (subdirectories, files, parents, etc.) will also
retain this type.

=item $foreign = Path::Class::File->new_foreign($type, @args)

Returns a C<Path::Class::File> object representing a file as it would
be specified on a system of type C<$type>.  Known types include
C<Unix>, C<Win32>, C<Mac>, C<VMS>, and C<OS2>, i.e. anything for which
there is a subclass of C<File::Spec>.

The arguments in C<@args> are the same as they would be specified in
C<new()>.

=item $fh = $file->open($mode, $permissions)

Passes the given arguments, including C<$file>, to C<< IO::File->new >>
(which in turn calls C<< IO::File->open >> and returns the result
as an C<IO::File> object.  If the opening
fails, C<undef> is returned and C<$!> is set.

=item $fh = $file->openr()

A shortcut for

 $fh = $file->open('r') or croak "Can't read $file: $!";

=item $fh = $file->openw()

A shortcut for

 $fh = $file->open('w') or croak "Can't write $file: $!";

=item $file->touch

Sets the modification and access time of the given file to right now,
if the file exists.  If it doesn't exist, C<touch()> will I<make> it
exist, and - YES! - set its modification and access time to now.

=item $file->slurp()

In a scalar context, returns the contents of C<$file> in a string.  In
a list context, returns the lines of C<$file> (according to how C<$/>
is set) as a list.  If the file can't be read, this method will throw
an exception.

If you want C<chomp()> run on each line of the file, pass a true value
for the C<chomp> or C<chomped> parameters:

  my @lines = $file->slurp(chomp => 1);

You may also use the C<iomode> parameter to pass in an IO mode to use
when opening the file, usually IO layers (though anything accepted by
the MODE argument of C<open()> is accepted here).  Just make sure it's
a I<reading> mode.

  my @lines = $file->slurp(iomode => ':crlf');
  my $lines = $file->slurp(iomode => '<:encoding(UTF−8)');

The default C<iomode> is C<r>.

=item $file->remove()

This method will remove the file in a way that works well on all
platforms, and returns a boolean value indicating whether or not the
file was successfully removed.

C<remove()> is better than simply calling Perl's C<unlink()> function,
because on some platforms (notably VMS) you actually may need to call
C<unlink()> several times before all versions of the file are gone -
the C<remove()> method handles this process for you.

=item $st = $file->stat()

Invokes C<< File::stat::stat() >> on this file and returns a
C<File::stat> object representing the result.

=item $st = $file->lstat()

Same as C<stat()>, but if C<$file> is a symbolic link, C<lstat()>
stats the link instead of the file the link points to.

=item $class = $file->dir_class()

Returns the class which should be used to create directory objects.

Generally overridden whenever this class is subclassed.

=back

=head1 AUTHOR

Ken Williams, kwilliams@cpan.org

=head1 SEE ALSO

Path::Class, Path::Class::Dir, File::Spec

=cut
