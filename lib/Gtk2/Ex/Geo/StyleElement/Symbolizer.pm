=pod

=head1 NAME

Gtk2::Ex::Geo::StyleElement::Symbolizer - A class for value(s) -> symbol converter

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $palette = Gtk2::Ex::Geo::StyleElement::Symbolizer->new( );

=head1 DESCRIPTION

Gtk2::Ex::Geo::Symbolizer is a tree of classes, which can convert a
property value (or property values) into a symbol. The simplest
symbolizer is a single symbol, while a complex symbolizer may use
several property values to compute a symbol.

In the GUI framework Gtk2::Ex::Geo::Symbolizer can be used as a model
for a Gtk2::Ex::Geo::Dialogs::Symbolizing view/controller (dialog).

=cut

package Gtk2::Ex::Geo::StyleElement::Symbolizer;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Class::Inspector;
use Clone;
use Gtk2::Ex::Geo::StyleElement;
use Glib qw/TRUE FALSE/;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement );

# PointSymbolizer
# made from Shape, Size, Color

1;
