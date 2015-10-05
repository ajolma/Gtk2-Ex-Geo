package Gtk2::Ex::Geo::Dialog::Symbolizing;

use strict;
use warnings;
use locale;
use Carp;
use Glib qw/TRUE FALSE/;

use base qw(Gtk2::Ex::Geo::Dialog);

## @method open_symbols_dialog($gui)
# @brief Open the symbols dialog for this layer.
sub open {
    my ($self) = @_;

    my $context = $self->{model}->{style}->{layer}->name.".".$self->{model}->{style}->{property};

    my $boot = $self->bootstrap('symbolizing_dialog', "Symbolizer for $context.");
    if ($boot) {
        $self->symbolizer_type('boot');
        $self->shape('boot');
        $self->property_name('boot');
        $self->property_value_range('boot');
        $self->size_range('boot');
        $self->dialog_manager('boot');
    }

    $self->symbolizer_type([$self->{model}->{style}->{layer}->symbolizer_types],
                           $self->{model}->readable_class_name);

}

# view: setup and accessors ($self->{model} should not be used here)

sub symbolizer_type {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->setup_combo('symbols_type_combobox');
        $self->get_widget('symbols_type_combobox')->signal_connect(changed => \&symbolizer_type_changed, $self);
    } elsif (defined $key) {
        $self->refill_combo('symbols_type_combobox', $key, $value);
    }
}

sub shape {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('combobox1');
        $self->get_widget('combobox1')->signal_connect(changed => \&shape_changed, $self);
    }  elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/label1 combobox1/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        print STDERR "set shapes to: @$name, sel=$x\n";
        $self->refill_combo('combobox1', $name, $x);
    } else {
        return $self->get_value_from_combo('combobox1');
    }
}

sub size {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
    }  elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/symbols_size_label symbols_size_spinbutton/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        $self->get_widget('symbols_size_spinbutton')->set_value($name);
    } else {
        return $self->get_widget('symbols_size_spinbutton')->get_value;
    }
}

sub property_name {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('symbols_field_combobox');
        $self->get_widget('symbols_field_combobox')->signal_connect(changed => \&property_name_changed, $self);
    }  elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/label73 symbols_field_combobox/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        $self->refill_combo('symbols_field_combobox', $name, $x);
    } else {
        return $self->get_value_from_combo('symbols_field_combobox');
    }
}

sub property_value_range {
    my ($self, $min, $max) = @_;
    if (defined $min && $min eq 'boot') {
        $self->get_widget('symbols_scale_button')->signal_connect(clicked => \&fill_property_value_range, $self);
        $self->get_widget('symbols_scale_min_entry')->signal_connect(changed => \&property_value_range_changed, $self);
        $self->get_widget('symbols_scale_max_entry')->signal_connect(changed => \&property_value_range_changed, $self);
    } elsif (defined $min && $min eq 'sensitive') {
        for my $w (qw/label74 symbols_scale_min_entry label75 symbols_scale_max_entry symbols_scale_button/) 
        {
            $self->get_widget($w)->set_sensitive($max);
        }
    } elsif (defined $max) {
        $self->get_widget('symbols_scale_min_entry')->set_text($min);
        $self->get_widget('symbols_scale_max_entry')->set_text($max);
    } else {
        $min = POSIX::strtod($self->get_widget('symbols_scale_min_entry')->get_text);
        $max = POSIX::strtod($self->get_widget('symbols_scale_max_entry')->get_text);
        return ($min, $max);
    }
}

sub size_range {
    my ($self, $min, $max) = @_;
    if (defined $min && $min eq 'boot') {
    } elsif (defined $min && $min eq 'sensitive') {
        for my $w (qw/symbols_size_label label2 symbols_size_spinbutton label77 spinbutton1/) 
        {
            $self->get_widget($w)->set_sensitive($max);
        }
    } elsif (defined $max) {
        $self->get_widget('symbols_size_spinbutton')->set_value($min);
        $self->get_widget('spinbutton1')->set_value($max);
    } else {
        $min = $self->get_widget('symbols_size_spinbutton')->get_value;
        $max = $self->get_widget('spinbutton1')->get_value;
        return ($min, $max);
    }
}

sub dialog_manager {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('symbols_apply_button')->signal_connect(clicked => \&apply, [$self, 0]);
        $self->get_widget('symbols_cancel_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('symbolizing_dialog')->signal_connect(delete_event => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('symbols_ok_button')->signal_connect(clicked => \&apply, [$self, 1]);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw//) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

# controller: callbacks for edits

sub apply {
    my ($self, $close) = @{$_[1]};
    $self->{model}->size($self->size);
    $self->{model}->size_range($self->size_range);
    $self->SUPER::apply($close);
}

sub symbolizer_type_changed {
    my ($combo, $self) = @_;
    my $symbolizer = $self->{model};
    
    my $symbolizer_type = $self->get_value_from_combo($combo);
    if (!$symbolizer->readable_class_name || $symbolizer->readable_class_name ne $symbolizer_type) {
        my $style = $symbolizer->{style};
        $symbolizer = Gtk2::Ex::Geo::StyleElement::Symbolizer->new( self => $symbolizer,
                                                                    readable_class_name => $symbolizer_type,
                                                                    style => $style );
    }

    # symbolizer may have fized or varying shape, fixed or varying size etc.

    my @shapes = $symbolizer->shapes;

    $self->shape(\@shapes, $symbolizer->shape);

    $self->shape(sensitive => @shapes != 0);

    my @size_range = $symbolizer->size_range;

    if (@size_range != 0) {
        my $property_name = $symbolizer->property();
        my @properties;
        my $properties = $symbolizer->{style}->{layer}->schema()->{Properties};
        for my $name (sort keys %$properties) {
            my $property = $properties->{$name};
            next unless $property->{Type};
            my $ok = $symbolizer->valid_property_type($property->{Type});
            next unless $ok;
            push @properties, $name;
        }
        $self->property_name(\@properties, $property_name);
        $self->property_name(sensitive => 1);
        $self->property_value_range(sensitive => 1);
        $self->size(sensitive => 0);
        $self->size_range(sensitive => 1);
        $self->size_range(@size_range);
    } else {
        $self->property_name([]);
        $self->property_name(sensitive => 0);
        $self->property_value_range(sensitive => 0);
        $self->size_range(sensitive => 0);
        $self->size(sensitive => 1);
        $self->size($symbolizer->size);
    }
    
}

sub shape_changed {
    my ($combo, $self) = @_;
}

sub property_name_changed {
    my ($combo, $self) = @_;
    my $symbolizer = $self->{model};
    my $property_name = $self->property_name;
    if (defined $property_name && $property_name ne '') {
        my $properties = $symbolizer->{style}->{layer}->schema()->{Properties};
        $symbolizer->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $symbolizer->property(undef);
    }
    $self->property_value_range('', '');
}

sub fill_property_value_range {
    my ($button, $self) = @_;
    my $symbolizer = $self->{model};
    my @range;
    my $property = $symbolizer->property;
    eval {
	@range = $symbolizer->{style}->{layer}->value_range($property);
    };
    if ($@) {
	$self->{glue}->message("$@");
	return;
    }
    $symbolizer->value_range(@range);
    $range[0] = '' unless defined $range[0];
    $range[1] = '' unless defined $range[1];
    $self->property_value_range(@range);
}

sub property_value_range_changed {
    my ($entry, $self) = @_;
    my $symbolizer = $self->{model};
    my ($min, $max) = $self->property_value_range;
    $symbolizer->value_range($min, $max);
}

1;
