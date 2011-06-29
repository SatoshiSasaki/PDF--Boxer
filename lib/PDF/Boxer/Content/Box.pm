package PDF::Boxer::Content::Box;
use Moose;
use DDP;
use Scalar::Util qw/weaken/;

has 'debug'   => ( isa => 'HashRef', is => 'ro', default => sub{{}} );

has 'margin'   => ( isa => 'ArrayRef', is => 'ro', default => sub{ [0,0,0,0] } );
has 'border'   => ( isa => 'ArrayRef', is => 'ro', default => sub{ [1,0,0,0] } );
has 'padding'  => ( isa => 'ArrayRef', is => 'ro', default => sub{ [0,0,0,0] } );
has 'children'  => ( isa => 'ArrayRef', is => 'rw', default => sub{ [] } );

with 'PDF::Boxer::Role::SizePosition';

has 'boxer' => ( isa => 'PDF::Boxer', is => 'ro' );
has 'parent'  => ( isa => 'Object', is => 'ro' );

has 'name' => ( isa => 'Str', is => 'ro' );
has 'type' => ( isa => 'Str', is => 'ro', default => 'Box' );
has 'background' => ( isa => 'Str', is => 'ro' );
has 'border_color' => ( isa => 'Str', is => 'ro' );

has 'font' => ( isa => 'Str', is => 'ro', default => 'Helvetica' );
has 'align' => ( isa => 'Str', is => 'ro', default => '' );

sub BUILDARGS{
  my ($class, $args) = @_;

  foreach my $attr (qw! margin border padding !){
    next unless exists $args->{$attr};
    my $arg = $args->{$attr};
    if (ref($arg)){
      unless (ref($arg) eq 'ARRAY'){
        die "Arg to $attr must be string or array reference";
      }
    } else {
      $arg = [split(/\s+/, $arg)];
    }
    my $val = [$arg->[0]];
    $val->[1] = defined $arg->[1] ? $arg->[1] : $val->[0];
    $val->[2] = defined $arg->[2] ? $arg->[2] : $val->[0];
    $val->[3] = defined $arg->[3] ? $arg->[3] : $val->[1];

    $args->{$attr} = $val;
  }

  return $args;
}

sub BUILD{
  my ($self) = @_;
  unless($self->parent){
    $self->adjust({
      margin_top => $self->boxer->max_height,
      margin_left => 0,
      margin_width => $self->boxer->max_width,
      margin_height => $self->boxer->max_height,
    },'self');
  }

  foreach my $child (@{$self->children}){
    $child->{boxer} = $self->boxer;
    $child->{debug} = $self->debug;
    $child->{font} ||= $self->font;
    $child->{align} ||= $self->align;
    my $weak_me = $self;
    weaken($weak_me);
    $child->{parent} = $weak_me;
    my $class = 'PDF::Boxer::Content::'.$child->{type};
    $child = $class->new($child);
  }

}

sub propagate{
  my ($self, $method, $args) = @_;
  return unless $method;
  my @kids = @{$self->children};
  if (@kids){
    foreach my $kid (@kids){
      $kid->$method($args);
    }
  }
  return @kids;
}

# initialize objects with default sizes
#  - text gets width of widest line and height of all lines (wrapped at page width)
#  - images get their scaled size
#  - rows get the height of their tallest child and the width of all of them
#  - columns get the width of their widest child and the height of all of them
#  - grids (same as columns)
#  - box gets the width of all it's kids (wrapped at page width) and the height of the line of kids

# if text or box are too wide they need to be resized and they're contents re-wrapped.
# this may result in their height increasing which needs to be communicated to their parent.
# the parent can then adjust itself accordingly.


sub initialize{
  my ($self) = @_;

  my @kids = $self->propagate('initialize');

  $self->update unless $self->parent;

  # the main box should stay wide open.
  return unless $self->parent;

  my ($width, $height) = $self->get_default_size;

  $self->set_width($width);
  $self->set_height($height);

  return 1;
}

# we get our size from the children
sub get_default_size{
  my ($self) = @_;
  my ($width, $height) = (0,0);
  my $kids = $self->children;
  if (@$kids){
    my ($widest, $highest, $x, $y) = (0, 0, 0); 
    foreach(@$kids){
      $highest = $_->margin_height if $_->margin_height > $highest;
      if ($width + $_->margin_width > $self->boxer->max_width){
        $height += $highest;
        $highest = 0;
        $widest = $width if $width > $widest;
      } else {
        $width += $_->margin_width;
      }
      $width = $width ? (sort($_->margin_width,$width))[1] : $_->margin_width;
    }
    $height += $highest;
  }# else {
  #  $width = $self->has_width ? $self->width : 0;
  #  $height = $self->has_height ? $self->height : 0;
  #}
  return ($width, $height);
}

sub update{
  my ($self) = @_;
  $self->update_children;
  return 1;
}

sub child_adjusted_height{}

sub update_children{
  my ($self) = @_;
  if ($self->position_set){
    my $kids = $self->children;
    if (@$kids){
      my ($highest, $x, $y) = (0, $self->content_left, $self->content_top); 
      foreach my $kid (@$kids){
        $highest = $kid->margin_height if $kid->margin_height > $highest;
        if ($x + $kid->margin_width > $self->width){
          $kid->move($x,$y);
          $y -= $highest;
          $highest = 0;
          $x = $self->content_left;
        } else {
          $kid->move($x,$y);
          $x += $kid->margin_width;
        }
      }
    }
  }
}

sub render{
  my ($self) = @_;

  my $gfx = $self->boxer->doc->gfx;

  if ($self->background){
    $gfx->fillcolor($self->background);
    $gfx->rect($self->border_left, $self->border_top, $self->border_width, -$self->border_height);
    $gfx->fill;
  }

  # === Need to change to respect all border sides sizes ===
  # increasing linewidth thickens the border "around" the lines of the rectangle.
  # we want to thinken "inside" the rectangle..
  if (my $width = $self->border->[0]){
    $gfx->linewidth(1);
    $gfx->strokecolor($self->border_color || 'black');
    my ($bl,$bt,$bw,$bh) = ($self->border_left, $self->border_top, $self->border_width, $self->border_height);
    foreach(1..$width){
      $gfx->rect($bl,$bt,$bw,-$bh);
      $gfx->stroke;
      $bl++; $bt--;
      $bw -= 2;
      $bh -= 2;
    }
  }

  foreach(@{$self->children}){
    $_->render;
  }

}

sub ruler_h{
  my ($self, $color) = @_;
  $color ||= 'blue';
  my $gfx = $self->boxer->doc->gfx;
  $gfx->strokecolor($color);
  $gfx->move(10,0);
  $gfx->vline($self->margin_height);
  my $y = 10;
  while ($y < $self->boxer->max_height){
    $gfx->move(10,$y);
    $gfx->hline($y % 50 ? 15 : 20);
    $y += 10;
  }
  $gfx->stroke;
}


__PACKAGE__->meta->make_immutable;

1;

__END__






sub size_and_position{
  my ($self) = @_;

#  my ($width, $height) = $self->kids_min_size;

  my $kid = $self->children->[0];

  if ($kid){
    $kid->adjust({
      margin_left => $self->content_left,
      margin_top => $self->content_top,
      margin_width => $self->content_width,
      margin_height => $self->content_height,
    },'parent');

    $self->propagate('size_and_position');
  }

  return 1;
}

sub tighten{
  my ($self) = @_;

  $self->propagate('tighten');

  my $kid = $self->children->[0];

  if ($kid){
    $self->adjust({
      content_bottom => $kid->margin_top,
    },'self');

  }

  return 1;
}

sub kids_min_size{
  my ($self) = @_;
  my $kid = $self->children->[0];
  return ($kid->margin_width, $kid->margin_height) if $kid;
  return (0,0);
}

sub add_marker{
  my ($self, $color) = @_;
  $color ||= 'blue';
  my $gfx = $self->boxer->doc->gfx;
  $gfx->linewidth(1);
  $gfx->strokecolor($color);
  $gfx->move($self->margin_left, $self->margin_top);
  $gfx->hline($self->margin_left + 3);
  $gfx->stroke;
  $gfx->move($self->margin_left, $self->margin_top);
  $gfx->vline($self->margin_top-3);
  $gfx->stroke;
}

sub cross_hairs{
  my ($self, $x, $y, $color) = @_;
  $color ||= 'blue';
  my $gfx = $self->boxer->doc->gfx;
  $gfx->strokecolor($color);
  $gfx->move($x,0);
  $gfx->vline($self->margin_height);
  $gfx->move(0,$y);
  $gfx->hline($self->margin_width);
  $gfx->stroke;
}

sub dump_all{
  my ($self) = @_;
  return unless $self->debug;
  warn "\n===========================\n";
  warn '=== '.$self->name. ' ==='."\n";
  warn $self->dump_spec;
  warn $self->dump_position;
  warn $self->dump_size;
  warn $self->dump_attr;
  warn "===========================\n";
  $self->add_marker;
}

sub dump_spec{
  my ($self) = @_;
  my @lines = (
    '== Spec ==',
    (sprintf 'Margin: %s %s %s %s', @{$self->margin}),
    (sprintf 'Border: %s %s %s %s', @{$self->border}),
    (sprintf 'Paddin: %s %s %s %s', @{$self->padding}),
  );
  $_ .= "\n" foreach @lines;
  return join('', @lines);
}

sub dump_attr{
  my ($self) = @_;
  my @lines = (
    '== Attr ==',
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
