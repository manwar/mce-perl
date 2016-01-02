###############################################################################
## ----------------------------------------------------------------------------
## Handle class for use with MCE::Shared.
##
###############################################################################

package MCE::Shared::Handle;

use strict;
use warnings;

no warnings qw( threads recursion uninitialized once );

our $VERSION = '1.699_001';

## no critic (TestingAndDebugging::ProhibitNoStrict)
## no critic (InputOutput::ProhibitTwoArgOpen)

use bytes;

sub TIEHANDLE {
   my $class = shift;
   if (ref $_[0] eq 'ARRAY') {
      # For use with MCE::Shared to reach the Server process
      # without a GLOB initially.
      bless $_[0], $class;
   }
   else {
      my $fh = \do { local *HANDLE };
      bless $fh, $class;
      $fh->OPEN(@_) if @_;
      $fh;
   }
}

## Based on Tie::StdHandle.

sub EOF     { eof($_[0]) }
sub TELL    { tell($_[0]) }
sub FILENO  { fileno($_[0]) }
sub SEEK    { seek($_[0], $_[1], $_[2]) }
sub CLOSE   { close($_[0]) }
sub BINMODE { binmode($_[0]) }

sub OPEN {
   $_[0]->CLOSE if defined($_[0]->FILENO);
   @_ == 2 ? open($_[0], $_[1]) : open($_[0], $_[1], $_[2]);
}

sub READ { &CORE::read(shift(), \shift(), @_) }
sub GETC { getc($_[0]) }

sub READLINE {
   # support special case; e.g. $/ = "\n>" for bioinformatics
   # anchoring ">" at the start of line

   if (length $/ > 1 && substr($/, 0, 1) eq "\n" && !eof $_[0]) {
      my ($len, $buf) = (length($/) - 1);

      if (tell $_[0]) {
         $buf = substr($/, 1), $buf .= readline($_[0]);
      } else {
         $buf = readline($_[0]);
      }
      substr($buf, -$len, $len, '')
         if (substr($buf, -$len) eq substr($/, 1));

      $buf;
   }
   else {
      scalar(readline($_[0]));
   }
}

sub PRINT {
   my $fh  = shift;
   my $buf = join(defined $, ? $, : "", @_);
   $buf   .= $\ if defined $\;
   local $\; # don't print any line terminator
   print $fh $buf;
}

sub PRINTF {
   my $fh  = shift;
   my $buf = sprintf(shift, @_);
   local $\; # ditto
   print $fh $buf;
}

sub WRITE {
   @_ > 2 ? syswrite($_[0], $_[1], $_[2], $_[3] || 0)
          : syswrite($_[0], $_[1]);
}

## Aliases.

{
   no strict 'refs';
   *{ __PACKAGE__.'::new' } = \&TIEHANDLE;
}

1;

__END__

###############################################################################
## ----------------------------------------------------------------------------
## Module usage.
##
###############################################################################

=head1 NAME

MCE::Shared::Handle - Class for sharing handles via MCE::Shared

=head1 VERSION

This document describes MCE::Shared::Handle version 1.699_001

=head1 SYNOPSIS

   use MCE::Hobo;
   use MCE::Shared;

   my $ofh = MCE::Shared->handle( '>>', \*STDOUT );
   my $ifh = MCE::Shared->handle(  '<', '/path/to/input/file' );

   # output is serialized (not garbled), but not ordered

   sub parallel {
      $/ = "\n"; # can set the input record separator
      while (my $line = <$ifh>) {
         printf {$ofh} "[%5d] %s", $., $line;
      }
   }

   MCE::Hobo->create( \&parallel ) for 1 .. 4;

   $_->join() for MCE::Hobo->list();

   # shared handle operations

   my $bool = eof($ifh);
   my $off  = tell($ifh);
   my $fd   = fileno($ifh);
   my $char = getc($ifh);
   my $line = readline($ifh);

   binmode $ifh;

   seek $ifh, 10, 0;
   read $ifh, my($buf), 80;

   print  {$ofh} "foo\n";
   printf {$ofh} "%s\n", "bar";

   open $ofh, ">>", \*STDERR;
   syswrite $ofh, "shared handle to STDERR\n";

   close $ifh;
   close $ofh;

=head1 DESCRIPTION

Helper class for L<MCE::Shared|MCE::Shared>.

=head1 API DOCUMENTATION

To be completed before the final 1.700 release.

=over 3

=item new

=back

=head1 CREDITS

Implementation inspired by L<Tie::StdHandle|Tie::StdHandle>.

=head1 INDEX

L<MCE|MCE>, L<MCE::Core|MCE::Core>, L<MCE::Shared|MCE::Shared>

=head1 AUTHOR

Mario E. Roy, S<E<lt>marioeroy AT gmail DOT comE<gt>>

=cut

