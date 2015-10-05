=pod

=head1 NAME

Gtk2::Ex::Geo::Style - A class for style information for geometric properties of geospatial features

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $style = Gtk2::Ex::Geo::Style->new( color => [0, 0, 0, 255] );

    $layer->assign_style($style, 'a_field');

=head1 DESCRIPTION

Gtk2::Ex::Geo::Style is information which is meant to be used when
features or elements of features are rendered.

Styling is a very large
topic. L<http://www.opengeospatial.org/standards/sld> defines an
approach. This module does not claim to cover the whole topic but be a
simple and extendable basis.

Style should be definable in text and interactively, using
dialogs. The Gtk2::Ex::Geo toolkit contains dialogs for defining basic
styles.

A style is always associated with only one geometric property (but one
geometry may have more than one style). The geometric property may be
a point, a curve, or a surface. Basic styling is using a (possibly
colored and varying size) symbol for a point, a line type (dash,
width, color) for a curve, and fill color for a surface. To render the
border line of a surface an additional style is needed. 

A style property (color, one of its elements, symbol size, symbol
type, dash type, line width) can be either static or linked to some
value (for example scalar valued field of the feature).

=cut

package Gtk2::Ex::Geo::Style;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Glib qw /TRUE FALSE/;
#use Gtk2::Ex::Geo::Rule;
use Gtk2::Ex::Geo::StyleElement::Symbolizer;
use Gtk2::Ex::Geo::StyleElement::ColorPalette;
use Gtk2::Ex::Geo::StyleElement::Labeling;
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

sub defaults {
    my $self = shift;
    my $coloring = Gtk2::Ex::Geo::ColorPalette->new( style => $self );
    my $color_dialog = Gtk2::Ex::Geo::Dialog::Coloring->new(glue => $self->{glue},
                                                            model => $coloring);
    
    my $symbolizing = Gtk2::Ex::Geo::Symbolizer->new( style => $self );
    my $symbol_dialog = Gtk2::Ex::Geo::Dialog::Symbolizing->new(glue => $self->{glue},
                                                                model => $symbolizing);
    
    my $labeling = Gtk2::Ex::Geo::Labeling->new( style => $self );
    my $labeling_dialog = Gtk2::Ex::Geo::Dialog::Labeling->new(glue => $self->{glue},
                                                               model => $labeling);
    
    return  {
        # coloring
        color_dialog => $color_dialog,

        include_border => 0,
        border_color => [],
        
        # symbolization
        symbol_dialog => $symbol_dialog,
        
        # labeling
        label_dialog => $labeling_dialog,
    };
}

sub initialize {
    my $self = shift;
    my %params = @_;

    $self->{glue} = $params{glue};
    $self->{layer} = $params{layer};
    $self->{property} = $params{property};

    croak "Style initializer missing layer or property." unless $self->{layer} && $self->{property};

    # set defaults for all, order of preference is: 
    # user given as constructor parameter
    # subclass default
    # default as defined here

    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        unless (ref $defaults->{$property}) {
            $self->{$property} = $defaults->{$property} unless exists $self->{$property};
            $self->{$property} = $params{$property} if exists $params{$property};
        } elsif (ref $defaults->{$property} eq 'ARRAY') {
            @{$self->{$property}} = @{$defaults->{$property}} unless exists $self->{$property};
            @{$self->{$property}} = @{$params{$property}} if exists $params{$property};
        } else { # currently this can only be an object
            $self->{$property} = $defaults->{$property} unless exists $self->{$property};
            $self->{$property} = $params{$property} if exists $params{$property};
        }
    }
    
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
    my ($self, $another_style) = @_;
    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        $self->{$property} = $another_style->{$property};
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

1;
