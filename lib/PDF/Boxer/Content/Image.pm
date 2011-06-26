package PDF::Boxer::Content::Image;
use Moose;
use namespace::autoclean;

extends 'PDF::Boxer::Content::Box';

has 'src' => ( isa => 'Str', is => 'ro' );
has 'scale' => ( isa => 'Num', is => 'ro' );
has 'format' => ( isa => 'Str', is => 'ro', lazy_build => 1 );

has 'image' => ( is => 'rw', lazy_build => 1 );
has 'image_width' => ( isa => 'Int', is => 'rw', lazy_build => 1 );
has 'image_height' => ( isa => 'Int', is => 'rw', lazy_build => 1 );

has 'align' => ( isa => 'Str', is => 'ro' );
has 'valign' => ( isa => 'Str', is => 'ro' );

sub _build_pressure_width{ 1 }
sub _build_pressure_height{ 0 }

sub _build_format{
  my ($self) = @_;
  return unless $self->src;
  my ($ext) = $self->src =~ /\.([^\.]+)$/;
  return $ext;
}

sub _build_image{
  my ($self) = @_;
  die $self->src.": $!" unless -f $self->src;
  my $pdf = $self->boxer->doc->pdf;
  my $method = 'image_'.$self->format;
  return $self->boxer->doc->pdf->$method($self->src);
}

sub _build_image_width{
  my ($self) = @_;
  my $width = $self->image->width;
  if (my $sc = $self->scale){
    $width = $width * $sc / 100;
  }
  return $width;
}

sub _build_image_height{
  my ($self) = @_;
  my $height = $self->image->height;
  if (my $sc = $self->scale){
    $height = $height * $sc / 100;
  }
  return $height;
}

sub set_minimum_size{
  my ($self) = @_;
  $self->width($self->image_width);
  $self->height($self->image_height);
  return ($self->image_width, $self->image_height);
}

around 'render' => sub{
  my ($orig, $self) = @_;

  my $img = $self->image;

  my $gfx = $self->boxer->doc->gfx;

  my $x = $self->content_left;
  my $y = $self->content_top-$self->height;

  my @args = $self->scale ? ($self->scale/100) : ($self->image->width, $self->image->height);

  if (my $al = $self->valign){
    if ($al eq 'top'){
      $y = $self->content_top - $self->image_height;
    } elsif ($al eq 'center'){
      my $bc = $self->content_top - ($self->content_height / 2);
      my $ic = $self->image_height / 2;
      $y = $bc - $ic;
    }
  }

  if (my $al = $self->align){
    if ($al eq 'right'){
      $x = $self->content_right - $self->image_width;
    } elsif ($al eq 'center'){
      my $bc = $self->content_left + ($self->content_width / 2);
      my $ic = $self->image_width / 2;
      $x = $bc - $ic;      
    }
  }

  $gfx->image($img, $x, $y, @args);

  $self->$orig();

};

sub dump_attr{
  my ($self) = @_;
  my @lines = (
    '== Image Attr ==',
    (sprintf 'width: %s', $self->width),
    (sprintf 'height: %s', $self->height),
  );
  $_ .= "\n" foreach @lines;
  return join('', @lines);
}

__PACKAGE__->meta->make_immutable;

1;

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Jason Galea <lecstor at cpan.org>. All rights reserved.

This library is free software and may be distributed under the same terms as perl itself.

=cut

