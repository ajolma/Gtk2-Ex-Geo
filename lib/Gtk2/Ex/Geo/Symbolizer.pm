=pod

=head1 NAME

Gtk2::Ex::Geo::Symbolizer - A class for symbolizer information for geometric properties of geospatial features

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $symbolizer = Gtk2::Ex::Geo::Symbolizer->new( color => [0, 0, 0, 255] );

    $layer->assign_symbolizer($symbolizer, 'a_field');

=head1 DESCRIPTION

Gtk2::Ex::Geo::Symbolizer is information which is meant to be used when
features or elements of features are rendered.

Styling is a very large
topic. L<http://www.opengeospatial.org/standards/sld> defines an
approach. This module does not claim to cover the whole topic but be a
simple and extendable basis.

Symbolizer should be definable in text and interactively, using
dialogs. The Gtk2::Ex::Geo toolkit contains dialogs for defining basic
symbolizers.

A symbolizer is always associated with only one geometric property (but one
geometry may have more than one symbolizer). The geometric property may be
a point, a curve, or a surface. Basic styling is using a (possibly
colored and varying size) symbol for a point, a line type (dash,
width, color) for a curve, and fill color for a surface. To render the
border line of a surface an additional symbolizer is needed. 

A symbolizer property (color, one of its elements, symbol size, symbol
type, dash type, line width) can be either static or linked to some
value (for example scalar valued field of the feature).

=cut

package Gtk2::Ex::Geo::Symbolizer;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Glib qw /TRUE FALSE/;
use Gtk2::Ex::Geo::StyleElement::Shape;
use Gtk2::Ex::Geo::StyleElement::Size;
use Gtk2::Ex::Geo::StyleElement::Color;
use Gtk2::Ex::Geo::StyleElement::Labeler;
use Gtk2::Ex::Geo::Dialog;
use Gtk2::Ex::Geo::Dialog::Symbolizing;
use Gtk2::Ex::Geo::Dialog::Coloring;
use Gtk2::Ex::Geo::Dialog::Labeling;

use vars qw//;

BEGIN {
     use Exporter 'import';
    our %EXPORT_TAGS = ( 'all' => [ qw() ] );
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
}

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub initialize {
    my $self = shift;
    my %params = @_;

    $self->{glue} = $params{glue};
    $self->{layer} = $params{layer};
    $self->{property} = $params{property};

    croak "Symbolizer initializer missing layer or property." unless $self->{layer} && $self->{property};

    $self->{color} = Gtk2::Ex::Geo::StyleElement::Color->new( symbolizer => $self );
    $self->{coloring_dialog} = Gtk2::Ex::Geo::Dialog::Coloring->new(glue => $self->{glue},
                                                                    model => $self->{color});
    
    $self->{symbolizer} = Gtk2::Ex::Geo::StyleElement::Symbolizer->new( symbolizer => $self );
    $self->{symbolizing_dialog} = Gtk2::Ex::Geo::Dialog::Symbolizing->new(glue => $self->{glue},
                                                                          model => $self->{symbolizer});
    
    $self->{labeler} = Gtk2::Ex::Geo::StyleElement::Labeler->new( symbolizer => $self );
    $self->{labeling_dialog} = Gtk2::Ex::Geo::Dialog::Labeling->new(glue => $self->{glue},
                                                                    model => $self->{labeler});
    
    $self->{include_border} = undef;        
    $self->{border_color} = [];
    
}

sub clone {
    my ($self) = @_;
    my %params;
    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        $params{$property} = $self->{$property};
    }
    my $clone = $self->new(%params);
}

sub restore_from {
    my ($self, $another_symbolizer) = @_;
    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        $self->{$property} = $another_symbolizer->{$property};
    }
}

sub include_border {
    my $self = shift;
    $self->{include_border} = shift if @_;
    return $self->{include_border};
}

sub border_color {
    my $self = shift;
    $self->{border_color} = [@_] if @_;
    return @{$self->{border_color}};
}

package Gtk2::Ex::Geo::Symbolizer::Point;
use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Gtk2::Ex::Geo::StyleElement::Shape;
use Gtk2::Ex::Geo::StyleElement::Size;
use Gtk2::Ex::Geo::StyleElement::Color;
use Gtk2::Ex::Geo::StyleElement::Labeler;
use Gtk2::Ex::Geo::Dialog;
use Gtk2::Ex::Geo::Dialog::Symbolizing;
use Gtk2::Ex::Geo::Dialog::Coloring;
use Gtk2::Ex::Geo::Dialog::Labeling;

our @ISA = qw/Gtk2::Ex::Geo::Symbolizer/;

sub initialize {
    my $self = shift;
    my %params = @_;

    $self->{glue} = $params{glue};
    $self->{layer} = $params{layer};
    $self->{property} = $params{property};

    croak "Symbolizer initializer missing layer or property." unless $self->{layer} && $self->{property};

    $self->{shape} = Gtk2::Ex::Geo::StyleElement::Shape->new( symbolizer => $self );
    $self->{size} = Gtk2::Ex::Geo::StyleElement::Size->new( symbolizer => $self );
    $self->{color} = Gtk2::Ex::Geo::StyleElement::Color->new( symbolizer => $self );

    my $model = { shape => $self->{shape},
                  size => $self->{size},
                  color => $self->{color} };
    bless $model => 'Gtk2::Ex::Geo::Model';

    $self->{view} = Gtk2::Ex::Geo::Dialog::Symbolizing->new( glue => $self->{glue},
                                                             layer => $self->{layer},
                                                             property => $self->{property},
                                                             model => $model );
    
    $self->{labeler} = Gtk2::Ex::Geo::StyleElement::Labeler->new( symbolizer => $self );
    $self->{labeling_dialog} = Gtk2::Ex::Geo::Dialog::Labeling->new(glue => $self->{glue},
                                                                    model => $self->{labeler});
    
    $self->{include_border} = undef;        
    $self->{border_color} = [];
    
}

1;
