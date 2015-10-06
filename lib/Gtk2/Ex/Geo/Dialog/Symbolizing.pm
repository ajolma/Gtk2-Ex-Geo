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

    my $context = $self->{layer}->name.".".$self->{property};

    my $boot = $self->bootstrap('point_symbolizer_dialog', "Symbolizer for $context.");
    if ($boot) {
        $self->shape_type('boot');
        $self->size_type('boot');
        $self->color_type('boot');
        $self->property_name('shape', 'boot');
        $self->property_name('size', 'boot');
        $self->property_name('color', 'boot');
        $self->shape('boot');
        $self->property_value_range('size', 'boot');
        $self->property_value_range('color', 'boot');
        $self->size_range('size', 'boot');
        $self->size_range('color', 'boot');
        $self->dialog_manager('boot');
    }

    $self->shape_type([$self->{layer}->shape_types], $self->{model}->{shape}->readable_class_name);
    $self->size_type([$self->{layer}->size_types], $self->{model}->{size}->readable_class_name);
    $self->color_type([$self->{layer}->color_types], $self->{model}->{color}->readable_class_name);

}

# view: setup and accessors ($self->{model} should not be used here)

sub shape_type {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('combobox2');
        $self->get_widget('combobox2')->signal_connect(changed => \&shape_type_changed, $self);
    } elsif (defined $name) {
        $self->refill_combo('combobox2', $name, $x);
    } else {
        return $self->get_value_from_combo('combobox2');
    }
}

sub size_type {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('combobox3');
        $self->get_widget('combobox3')->signal_connect(changed => \&size_type_changed, $self);
    } elsif (defined $name) {
        $self->refill_combo('combobox3', $name);
    } else {
        return $self->get_widget('combobox3')->get_value;
    }
}

sub color_type {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('combobox4');
        $self->get_widget('combobox4')->signal_connect(changed => \&color_type_changed, $self);
    } elsif (defined $name) {
        $self->refill_combo('combobox4', $name);
    } else {
        return $self->get_widget('combobox4')->get_value;
    }
}

sub property_name {
    my ($self, $dim, $name, $x) = @_;
    if ($dim eq 'shape') {
        if (defined $name && $name eq 'boot') {
            $self->setup_combo('shape_property_combobox');
            $self->get_widget('shape_property_combobox')->signal_connect(changed => \&shape_property_name_changed, $self);
        }  elsif (defined $name && $name eq 'sensitive') {
            for my $w (qw/label3 shape_property_combobox/) 
            {
                $self->get_widget($w)->set_sensitive($x);
            }
        } elsif (defined $name) {
            $self->refill_combo('shape_property_combobox', $name, $x);
        } else {
            return $self->get_value_from_combo('shape_property_combobox');
        }
    } elsif ($dim eq 'size') {
        if (defined $name && $name eq 'boot') {
            $self->setup_combo('size_property_combobox');
            $self->get_widget('size_property_combobox')->signal_connect(changed => \&size_property_name_changed, $self);
        }  elsif (defined $name && $name eq 'sensitive') {
            for my $w (qw/label73 size_property_combobox/) 
            {
                $self->get_widget($w)->set_sensitive($x);
            }
        } elsif (defined $name) {
            $self->refill_combo('size_property_combobox', $name, $x);
        } else {
            return $self->get_value_from_combo('size_property_combobox');
        }
    } else  {
        if (defined $name && $name eq 'boot') {
            $self->setup_combo('combobox5');
            $self->get_widget('combobox5')->signal_connect(changed => \&color_property_name_changed, $self);
        }  elsif (defined $name && $name eq 'sensitive') {
            for my $w (qw/label8 combobox5/) 
            {
                $self->get_widget($w)->set_sensitive($x);
            }
        } elsif (defined $name) {
            $self->refill_combo('combobox5', $name, $x);
        } else {
            return $self->get_value_from_combo('combobox5');
        }
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
        $self->refill_combo('combobox1', $name);
    } else {
        return $self->get_widget('combobox1')->get_value;
    }
}

sub property_value_range {
    my ($self, $dim, $min, $max) = @_;
    if ($dim eq 'size') {
        if (defined $min && $min eq 'boot') {
            $self->get_widget('symbols_scale_button')->signal_connect(clicked => \&fill_size_property_value_range, $self);
            $self->get_widget('symbols_scale_min_entry')->signal_connect(changed => \&size_property_value_range_changed, $self);
            $self->get_widget('symbols_scale_max_entry')->signal_connect(changed => \&size_property_value_range_changed, $self);
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
    } elsif ($dim eq 'color') {
        if (defined $min && $min eq 'boot') {
            $self->get_widget('button1')->signal_connect(clicked => \&fill_color_property_value_range, $self);
            $self->get_widget('entry1')->signal_connect(changed => \&color_property_value_range_changed, $self);
            $self->get_widget('entry2')->signal_connect(changed => \&color_property_value_range_changed, $self);
        } elsif (defined $min && $min eq 'sensitive') {
            for my $w (qw/label9 entry1 label10 entry2 button1/) 
            {
                $self->get_widget($w)->set_sensitive($max);
            }
        } elsif (defined $max) {
            $self->get_widget('entry1')->set_text($min);
            $self->get_widget('entry2')->set_text($max);
        } else {
            $min = POSIX::strtod($self->get_widget('entry1')->get_text);
            $max = POSIX::strtod($self->get_widget('entry2')->get_text);
            return ($min, $max);
        }
    }
}

sub size {
    my ($self, $dim, $name, $x) = @_;
    if ($dim eq 'size') {
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
}

sub size_range {
    my ($self, $dim, $min, $max) = @_;
    if ($dim eq 'size') {
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
    } elsif ($dim eq 'color') {
        if (defined $min && $min eq 'boot') {
        } elsif (defined $min && $min eq 'sensitive') {
            for my $w (qw/ps_rainbow_label ps_min_hue_label ps_min_hue_button ps_hue_range_combobox ps_max_hue_label ps_max_hue_button/) 
            {
                $self->get_widget($w)->set_sensitive($max);
            }
        } elsif (defined $max) {
            $self->get_widget('ps_min_hue_label')->set_text($min);
            $self->get_widget('ps_max_hue_label')->set_text($max);
        } else {
            $min = $self->get_widget('ps_min_hue_label')->get_text;
            $max = $self->get_widget('ps_max_hue_label')->get_text;
            return ($min, $max);
        }
    }
}

sub dialog_manager {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('symbols_apply_button')->signal_connect(clicked => \&apply, [$self, 0]);
        $self->get_widget('symbols_cancel_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('point_symbolizer_dialog')->signal_connect(delete_event => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
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

sub shape_type_changed {
    my ($combo, $self) = @_;
    my $shape = $self->{model}->{shape};
    my $shape_type = $self->get_value_from_combo($combo);
    if (!$shape->readable_class_name || $shape->readable_class_name ne $shape_type) {
        $self->{model}->{shape} = Gtk2::Ex::Geo::StyleElement::Shape->new( readable_class_name => $shape_type,
                                                                           symbolizer => $self->{model}->{shape}->{symbolizer} );
        $shape = $self->{model}->{shape};
    }
    my $property_name = $shape->property();
    my @properties;
    my $properties = $self->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $type = $properties->{$name}->{Type};
        #print STDERR "prop $name,$type,",$shape->valid_property_type($type),"\n";
        next unless $type && $shape->valid_property_type($type);
        push @properties, $name;
    }
    $self->property_name('shape', \@properties, $property_name);
    $self->property_name('shape', sensitive => @properties);
    if (!$shape->isa('Gtk2::Ex::Geo::StyleElement::Shape::Simple')) {
        $self->shape([]);
        $self->shape(sensitive => 0);
    } else {
        $self->shape([$shape->shapes], $shape->shape);
        $self->shape(sensitive => 1);
    }
    $shape->set_view($self->get_widget('symbol_shape_treeview'));
    $shape->prepare_model();    
}

sub size_type_changed {
    my ($combo, $self) = @_;
    my $size = $self->{model}->{size};
    my $size_type = $self->get_value_from_combo($combo);
    if (!$size->readable_class_name || $size->readable_class_name ne $size_type) {
        $self->{model}->{size} = Gtk2::Ex::Geo::StyleElement::Size->new( readable_class_name => $size_type,
                                                                         style => $self->{model}->{size}->{style} );
        $size = $self->{model}->{size};
    }
    my $property_name = $size->property();
    my @properties;
    my $properties = $self->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $type = $properties->{$name}->{Type};
        next unless $type && $size->valid_property_type($type);
        push @properties, $name;
    }
    $self->property_name('size', \@properties, $property_name);
    $self->property_name('size', sensitive => @properties);
    my @size_range = $size->size_range;
    if (@size_range != 0) {
        $self->size(sensitive => 0);
        $self->size_range('size', sensitive => 1);
        $self->size_range('size', @size_range);
    } else {
        $self->size_range('size', sensitive => 0);
        $self->size(sensitive => 1);
    }
    $self->property_value_range('size', sensitive => !$size->isa('Gtk2::Ex::Geo::StyleElement::Size::Simple'));
    $size->set_view($self->get_widget('symbol_size_treeview'));
    $size->prepare_model();
}

sub color_type_changed {
    my ($combo, $self) = @_;
    my $color = $self->{model}->{color};
    my $color_type = $self->get_value_from_combo($combo);
    if (!$color->readable_class_name || $color->readable_class_name ne $color_type) {
        $self->{model}->{color} = Gtk2::Ex::Geo::StyleElement::Color->new( readable_class_name => $color_type,
                                                                           style => $self->{model}->{color}->{style} );
        $color = $self->{model}->{color};
    }
    my $property_name = $color->property();
    my @properties;
    my $properties = $self->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $type = $properties->{$name}->{Type};
        next unless $type && $color->valid_property_type($type);
        push @properties, $name;
    }
    $self->property_name('color', \@properties, $property_name);
    $self->property_name('color', sensitive => @properties);
    my @color_range = $color->hue_range;
    if (@color_range != 0) {
        $self->size_range('color', sensitive => 1);
        $self->size_range('color', @color_range);
    } else {
        $self->size_range('color', sensitive => 0);
    }
    $self->property_value_range('color', sensitive => !$color->isa('Gtk2::Ex::Geo::StyleElement::Color::SingleColor'));
    $color->set_view($self->get_widget('point_symbolizer_color_treeview'));
    $color->prepare_model();
}

sub shape_changed {
    my ($combo, $self) = @_;
}

sub shape_property_name_changed {
    my ($combo, $self) = @_;
    my $shape = $self->{model}->{shape};
    my $property_name = $self->property_name('shape');
    if (defined $property_name && $property_name ne '') {
        my $properties = $self->{layer}->schema()->{Properties};
        $shape->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $shape->property(undef);
    }
}

sub size_property_name_changed {
    my ($combo, $self) = @_;
    my $size = $self->{model}->{size};
    my $property_name = $self->property_name('size');
    if (defined $property_name && $property_name ne '') {
        my $properties = $self->{layer}->schema()->{Properties};
        $size->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $size->property(undef);
    }
    $self->property_value_range('size', '', '');
}

sub color_property_name_changed {
    my ($combo, $self) = @_;
    my $color = $self->{model}->{color};
    my $property_name = $self->property_name('color');
    if (defined $property_name && $property_name ne '') {
        my $properties = $self->{layer}->schema()->{Properties};
        $color->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $color->property(undef);
    }
    $self->property_value_range('color', '', '');
}

sub fill_size_property_value_range {
    my ($button, $self) = @_;
    my $size = $self->{model}->{size};
    my @range;
    my $property = $size->property();
    eval {
	@range = $self->{layer}->value_range($property);
    };
    if ($@) {
	$self->{glue}->message("$@");
	return;
    }
    $size->value_range(@range);
    $range[0] = '' unless defined $range[0];
    $range[1] = '' unless defined $range[1];
    $self->property_value_range(@range);
    $size->update_model;
}

sub size_property_value_range_changed {
    my ($entry, $self) = @_;
    my $size = $self->{model}->{size};
    my ($min, $max) = $self->property_value_range;
    $size->value_range($min, $max);
    $size->update_model;
}

sub fill_color_property_value_range {
    my ($button, $self) = @_;
    my $color = $self->{model}->{color};
    my @range;
    my $property = $color->property();
    eval {
	@range = $self->{layer}->value_range($property);
    };
    if ($@) {
	$self->{glue}->message("$@");
	return;
    }
    $color->value_range(@range);
    $range[0] = '' unless defined $range[0];
    $range[1] = '' unless defined $range[1];
    $self->property_value_range(@range);
    $color->update_model;
}

sub color_property_value_range_changed {
    my ($entry, $self) = @_;
    my $color = $self->{model}->{color};
    my ($min, $max) = $self->property_value_range;
    $color->value_range($min, $max);
    $color->update_model;
}

1;
