=pod

=head1 NAME

Gtk2::Ex::Geo::StyleElement::Shape - A class for value(s) -> shape converter

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $palette = Gtk2::Ex::Geo::StyleElement::Shape->new( );

=head1 DESCRIPTION

Gtk2::Ex::Geo::Shape is a tree of classes, which can convert a
property value (or property values) into a shape.

=cut

package Gtk2::Ex::Geo::StyleElement::Shape;

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

sub shape {
}

sub shapes {
    return qw/Square Circle Cross/;
}

package Gtk2::Ex::Geo::StyleElement::Shape::Simple;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Shape );

sub order {
    return 1;
}

sub readable_class_name {
    return 'Simple';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{shape} = 'Square';
    $self->{shape} = $params{shape} if exists $params{shape};
    $self->{property_name} = undef;
    $self->{property_type} = undef;
}

sub shape {
    my $self = shift;
    $self->{shape} = shift if @_;
    return $self->{shape};
}

package Gtk2::Ex::Geo::StyleElement::Shape::Lookup;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Shape Gtk2::Ex::Geo::StyleElement::Lookup );

sub order {
    return 2;
}

sub readable_class_name {
    return 'Lookup table';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{shape_table} = {};
    $self->{shape_table} = Clone::clone($params{shape_table}) if exists $params{shape_table};
}

sub valid_property_type {
    my ($self, $type) = @_;
    return unless $type;
    return $type eq 'Integer' || $type eq 'String';
}

sub shape {
    my ($self, $key, $shape) = @_;
    $self->{table}->{$key} = $shape if defined $shape;
    return $self->{table}->{$key} if exists $self->{table}->{$key};
}

package Gtk2::Ex::Geo::StyleElement::Shape::Bins;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Shape Gtk2::Ex::Geo::StyleElement::Bins );

sub order {
    return 3;
}

sub readable_class_name {
    return 'Bins';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{shape_table} = [];
    $self->{shape_table} = Clone::clone($params{shape_table}) if exists $params{shape_table};
}

sub valid_property_type {
    my ($self, $type) = @_;
    return unless $type;
    return $type eq 'Integer' || $type eq 'Real';
}

1;
