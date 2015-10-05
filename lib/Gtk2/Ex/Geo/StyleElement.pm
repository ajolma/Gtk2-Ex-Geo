package Gtk2::Ex::Geo::StyleElement;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Class::Inspector;
use Clone;

sub order { # for the GUI
}

sub readable_class_name { # for the GUI
}

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    if ($params{readable_class_name}) {
        my $base_class = $class;
        my $subclass_names = Class::Inspector->subclasses( $base_class );
        for my $subclass (@$subclass_names) {
            my $name = eval $subclass.'->readable_class_name';
            if ($name && $name eq $params{readable_class_name}) {
                $class = $subclass;
                last;
            }
        }
        croak "Unknown subclass of $base_class: '$params{readable_class_name}'." unless $class;
    }
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub initialize {
    my $self = shift;
    my %params = @_;
    $self->{property_name} = undef;
    $self->{property_name} = $params{property_name};
    $self->{property_type} = undef;
    $self->{property_type} = $params{property_type};
    $self->{style} = undef;
    $self->{style} = $params{style};
}

sub clone {
    my ($self, $from) = @_;
    if ($from) {
        for my $property (keys %$self) {
            delete $self->{$property};
        }
        my $style = $from->{style};
        delete $from->{style};
        my $clone = Clone::clone($from);
        bless $self => ref($clone);
        for my $property (keys %$clone) {
            $self->{$property} = $clone->{$property};
        }
        $self->{style} = $style;
    } else {
        my $style = $self->{style};
        delete $self->{style};
        my $clone = Clone::clone($self);
        $self->{style} = $style;
        $clone->{style} = $style;
        return $clone;
    }
}

sub property {
    my $self = shift;
    if (@_) {
        $self->{property_name} = shift;
        my $type = shift;
        if ($type and not $self->valid_property_type($type)) {
            $self->{property_name} = undef;
            $self->{property_type} = undef;
            croak "Invalid property type: '$type' for $self.";
        }
        $self->{property_type} = $type;
    }
    return wantarray ? ($self->{property_name}, $self->{property_type}) : $self->{property_name};
}

sub valid_property_type {
}

sub property_type_for_GTK {
    my $self = shift;
    my $type = $self->{property_type};
    return unless $type;
    return 'Int' if $type eq 'Integer';
    return 'Double' if $type eq 'Real';
    return 'String' if $type eq 'String';
}

sub serialize {
    my ($self, $filehandle, $format) = @_;
}

sub de_serialize {
    my ($self, $filehandle, $format) = @_;
}

1;
