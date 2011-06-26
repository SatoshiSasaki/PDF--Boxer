package PDF::Boxer::SpecParser;
use Moose;
use namespace::autoclean;

use XML::Parser;

has 'clean_whitespace' => ( isa => 'Bool', is => 'ro', default => 1 );

has 'xml_parser' => ( isa => 'XML::Parser', is => 'ro', lazy_build => 1 );

sub _build_xml_parser{
  XML::Parser->new(Style => 'Tree');
}

sub parse{
  my ($self, $xml) = @_;
  my $data = $self->xml_parser->parse($xml);

  my $spec = {};
  $self->mangle_spec($spec, $data);
  $spec = $spec->{children}[0];

  return $spec;
}

sub mangle_spec{
  my ($self, $spec, $data) = @_;
  while(@$data){
    my $tag = shift @$data;
    my $element = shift @$data;
    if ($tag eq '0'){
#      push(@{$spec->{value}}, $element);
    } elsif ($tag eq 'text'){
warn Data::Dumper->Dumper($spec, $element);
      $element->[0]{type} = 'Text';
      my $kid = shift @$element;
      $kid->{value} = [$self->clean_text($element->[1])];
      push(@{$spec->{children}}, $kid);
warn Data::Dumper->Dumper($spec);
#exit;
    } elsif ($tag eq 'textblock'){
      $element->[0]{type} = 'TextBlock';
      my $kid = shift @$element;
      $kid->{value} = [$self->clean_text($element->[1])];
      push(@{$spec->{children}}, $kid);
    } elsif (lc($tag) eq 'image'){
      $element->[0]{type} = 'Image';
      push(@{$spec->{children}}, shift @$element);
    } elsif (lc($tag) eq 'row'){
      $element->[0]{type} = 'Row';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    } elsif (lc($tag) eq 'column'){
      $element->[0]{type} = 'Column';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    } elsif (lc($tag) eq 'grid'){
      $element->[0]{type} = 'Grid';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    } else {
      $element->[0]{type} = 'Box';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    }
  }
}
#warn Data::Dumper->Dumper($spec, $element);

sub clean_text{
  my ($self, $element) = @_;
  return if $element =~ /^[\s\n\r]*$/;
  if ($self->clean_whitespace){
    $element =~ s/^[\s\n\r]+//;
    $element =~ s/[\s\n\r]+$//;
  }
  my @el = split(/\n/,$element);
  if ($self->clean_whitespace){
    foreach(@el){
      s/^\s+//;
      s/\s+$//;
    }
  }
  return @el;
}

sub mangle_spec1{
  my ($self, $spec, $data) = @_;
  while(@$data){
    my $tag = shift @$data;
    my $element = shift @$data;
    if ($tag eq '0'){
      next if $element =~ /^[\s\n\r]*$/;
      
      if ($self->clean_whitespace){
        $element =~ s/^[\s\n\r]+//;
        $element =~ s/[\s\n\r]+$//;
      }
      my @el = split(/\n/,$element);
      if ($self->clean_whitespace){
        foreach(@el){
          s/^\s+//;
          s/\s+$//;
        }
      }
      $spec->{type} = 'Text';
      $spec->{value} = \@el;
    } elsif (lc($tag) eq 'image'){
#warn Data::Dumper->Dumper($spec, $element);
      $element->[0]{type} = 'Image';
      push(@{$spec->{children}}, shift @$element);
    } elsif (lc($tag) eq 'row'){
      $element->[0]{type} = 'Row';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    } elsif (lc($tag) eq 'column'){
      $element->[0]{type} = 'Column';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    } elsif (lc($tag) eq 'grid'){
      $element->[0]{type} = 'Grid';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    } else {
      $element->[0]{type} = 'Box';
      push(@{$spec->{children}}, shift @$element);
      $self->mangle_spec($spec->{children}->[-1], $element);
    }
  }
}

__PACKAGE__->meta->make_immutable;

1;

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Jason Galea <lecstor at cpan.org>. All rights reserved.

This library is free software and may be distributed under the same terms as perl itself.

=cut

