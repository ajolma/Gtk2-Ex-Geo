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
    $self->{symbolizer} = undef;
    $self->{symbolizer} = $params{symbolizer};
}

sub clone {
    my ($self, $from) = @_;
    if ($from) {
        for my $property (keys %$self) {
            delete $self->{$property};
        }
        my $style = $from->{symbolizer};
        delete $from->{symbolizer};
        my $clone = Clone::clone($from);
        bless $self => ref($clone);
        for my $property (keys %$clone) {
            $self->{$property} = $clone->{$property};
        }
        $self->{symbolizer} = $style;
    } else {
        my $style = $self->{symbolizer};
        delete $self->{symbolizer};
        my $clone = Clone::clone($self);
        $self->{symbolizer} = $style;
        $clone->{symbolizer} = $style;
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

sub serialize {
    my ($self, $filehandle, $format) = @_;
}

sub deserialize {
    my ($self, $filehandle, $format) = @_;
}

sub property_type_for_GTK {
    my $self = shift;
    my $type = $self->{property_type};
    return unless $type;
    return 'Int' if $type eq 'Integer';
    return 'Double' if $type eq 'Real';
    return 'String' if $type eq 'String';
}

sub set_view {
    my ($self, $view) = @_;
    $self->{view} = $view;
    $self->{model} = undef;
    my $model = $self->{view}->get_model;
    if ($model) {
        for my $col ($self->{view}->get_columns) {
            $self->{view}->remove_column($col);
        }
        $model->clear;
    }
}

sub prepare_model {
    my ($self) = @_;
    return unless $self->{view};
    my $model = $self->{view}->get_model;
    $model->clear if $model;
    for my $col ($self->{view}->get_columns) {
        $self->{view}->remove_column($col);
    }
}

sub set_style_to_model {
}

package Gtk2::Ex::Geo::StyleElement::Linear;
use locale;
use Carp;

sub update_model {
    my ($self) = @_;
    return unless $self->{model};
    $self->{model}->clear;
    my ($min, $max) = $self->value_range;
    return unless defined $min && $min ne '' && defined $max && $max ne '';
    my $delta = ($max-$min)/14;
    return if $delta <= 0;
    my $x = $max;
    for my $i (1..15) {
	my $iter = $self->{model}->append(undef);
        my @style = $self->style($x);
        $self->set_style_to_model($iter, $x, @style);
	$x -= $delta;
	$x = $min if $x < $min;
    }
}

package Gtk2::Ex::Geo::StyleElement::Lookup;
use locale;
use Carp;

sub update_model {
    my ($self) = @_;
    #print STDERR "update model of $self\n";
    return unless $self->{model};
    $self->{model}->clear;
    if ($self->{property_type} eq 'String') {
        for my $key (sort keys %{$self->{table}}) {
            my $iter = $self->{model}->append(undef);
            my @style = $self->style($key);
            $self->set_style_to_model($iter, $key, @style);
        }
    } else {
        for my $key (sort {$a <=> $b} keys %{$self->{table}}) {
            my $iter = $self->{model}->append(undef);
            my @style = $self->style($key);
            $self->set_style_to_model($iter, $key, @style);
        }
    }
}

package Gtk2::Ex::Geo::StyleElement::Bins;
use locale;
use Carp;

sub organize {
    my $self = shift;
    my @sort;
    my $n = @{$self->{table}}-1;
    for (my $i = 0; $i < $n; $i++) {
        push @sort, [$self->{table}->[$i]->[0], $i];
    }
    my $last = $self->{table}->[$n];
    @sort = sort {$a->[0]<=>$b->[0]} @sort;
    my @new;
    for my $value_and_index (@sort) {
        push @new, $self->{table}->[$value_and_index->[1]];
    }
    push @new, $last;
    $self->{table} = \@new;
}

sub index {
    my ($self, $value) = @_;
    my $table = $self->{table};
    return 0 if $value <= $table->[0]->[0];
    my $index = 1;
    while ($index < $#$table) {
        return $index if $value <= $table->[$index]->[0];
        $index++;
    }
    return $index;
}

sub update_model {
    my ($self) = @_;
    #print STDERR "update model of $self\n";
    return unless $self->{model};
    $self->{model}->clear;
    my $i = 0;
    my $n = @{$self->{table}};
    for my $value_and_style (@{$self->{table}}) {
        my $iter = $self->{model}->append(undef);
        $value_and_style->[0] = 'inf' if $i == $n-1;
        $self->set_style_to_model($iter, @$value_and_style);
        $i++;
    }
}

package Gtk2::Ex::Geo::Model;
use locale;
use Carp;

sub clone {
    my ($self, $from) = @_;
    if ($from) {
        my $clone = Clone::clone($from);
        bless $self => ref($clone);
        for my $property (keys %$clone) {
            $self->{$property} = $clone->{$property};
        }
    } else {
        my $clone = Clone::clone($self);
        return $clone;
    }
}

1;
