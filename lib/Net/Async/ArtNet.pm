#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Net::Async::ArtNet;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw( IO::Async::Socket );

use IO::Socket::INET;
use Socket qw( SOCK_DGRAM );

=head1 NAME

C<Net::Async::ArtNet> - use ArtNet with C<IO::Async>

=head1 DESCRIPTION

This object class allows you to use the Art-Net protocol with C<IO::Async>.
It receives Art-Net frames containing DMX data.

=cut

=head1 EVENTS

=head2 on_dmx $seq, $phy, $uni, $data

A new set of DMX control values has been received. C<$seq> contains the
sequence number from the packet, C<$phy> and C<$uni> the physical and universe
numbers, and C<$data> will be an ARRAY reference containing up to 512 DMX
control values.

=cut

=head1 PARAMETERS

The following named parameters may be passed to C<new> or C<configure>:

=over 8

=item port => INT

Optional. Port number to listen for Art-Net packets on.

=back

=cut

sub _init
{
   my $self = shift;
   $self->SUPER::_init( @_ );

   $self->{port} = 0x1936; # Art-Net
}

sub configure
{
   my $self = shift;
   my %params = @_;

   foreach (qw( port on_dmx )) {
      $self->{$_} = delete $params{$_} if exists $params{$_};
   }

   $self->SUPER::configure( %params );
}

sub on_recv
{
   my $self = shift;
   my ( $packet ) = @_;

   my ( $magic, $opcode, $verhi, $verlo ) =
      unpack( "a8 v C C", substr $packet, 0, 12, "" );

   return unless $magic eq "Art-Net\0";
   return unless $verhi == 0 and $verlo == 14;

   if( $opcode == 0x5000 ) {
      my ( $seq, $phy, $universe, $data ) =
         unpack( "C C v xx a*", $packet );
      $self->maybe_invoke_event( on_dmx => $seq, $phy, $universe, [ unpack "C*", $data ] );
   }
}

sub _add_to_loop
{
   my $self = shift;
   my ( $loop ) = @_;

   if( !defined $self->read_handle ) {
      # TODO: IP?
      my $sock = IO::Socket::INET->new(
         Proto => "udp",
         Type  => SOCK_DGRAM,
         ReusePort => 1,
         ReuseAddr => 1,
         LocalPort => $self->{port},
      ) or die "Cannot socket() - $@";

      $self->set_handle( $sock );
   }

   $self->SUPER::_add_to_loop( @_ );
}

=head1 SEE ALSO

=over 4

=item *

L<http://en.wikipedia.org/wiki/Art-Net> - Art-Net - Wikipedia

=back

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
