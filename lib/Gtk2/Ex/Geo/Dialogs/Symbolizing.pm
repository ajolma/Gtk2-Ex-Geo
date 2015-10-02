package Gtk2::Ex::Geo::Dialogs::Symbolizing;

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

    my $boot = $self->bootstrap('symbolizing_dialog', 
                                "Symbolizer for ".$self->{model}->{style}->{layer}->name.".".$self->{model}->{style}->{property});
    if ($boot) {
        $self->symbolizer_type('boot');
        $self->property_name('boot');
        $self->property_value_range('boot');
        $self->size_range('boot');
        $self->dialog_manager('boot');
    }

    $self->{model_backup} = $self->{model}->clone;
    
    # set up the controllers
    $self->symbolizer_type('reset');

}

# view: setup and accessors

sub symbolizer_type {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->setup_combo('symbols_type_combobox');
        $self->get_widget('symbols_type_combobox')->signal_connect(changed => \&symbolizer_type_changed, $self);
    } elsif (defined $key && $key eq 'reset') {
        $self->refill_combo('symbols_type_combobox',
                            [$self->{model}->{style}->{layer}->symbolizer_types],
                            $self->{model}->readable_class_name);
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
        my $name = $self->get_value_from_combo('symbols_field_combobox');
        return ($name);
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
        $self->get_widget('symbols_scale_button')->signal_connect(clicked => \&fill_property_value_range, $self);
        $self->get_widget('symbols_scale_min_entry')->signal_connect(changed => \&property_value_range_changed, $self);
        $self->get_widget('symbols_scale_max_entry')->signal_connect(changed => \&property_value_range_changed, $self);
    } elsif (defined $min && $min eq 'sensitive') {
        for my $w (qw/symbols_size_label symbols_size_spinbutton/) 
        {
            $self->get_widget($w)->set_sensitive($max);
        }
    } elsif (defined $max) {
        $self->get_widget('symbols_size_spinbutton')->set_value($max);
    } else {
        $min = 0;
        $max = $self->get_widget('symbols_size_spinbutton')->get_value;
        return ($min, $max);
    }
}

sub dialog_manager {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('symbols_apply_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::apply, [$self, 0]);
        $self->get_widget('symbols_cancel_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('symbolizing_dialog')->signal_connect(delete_event => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('symbols_ok_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::apply, [$self, 1]);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw//) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

# controller: callbacks for edits

sub symbolizer_type_changed {
    my ($combo, $self) = @_;
    my $symbolizer = $self->{model};
    
    my $symbolizer_type = $self->get_value_from_combo($combo);
    if (!$symbolizer->readable_class_name || $symbolizer->readable_class_name ne $symbolizer_type) {
        my $style = $symbolizer->{style};
        $symbolizer = Gtk2::Ex::Geo::Symbolizer->new( self => $symbolizer,
                                                      readable_class_name => $symbolizer_type,
                                                      style => $style );
    }

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

    $self->property_name(sensitive => 0);
    $self->property_value_range(sensitive => 0);
    $self->size_range(sensitive => 0);

    if ($symbolizer->valid_property_type('Integer')) { # supports properties
        $self->property_name(sensitive => 1);
        $self->property_value_range(sensitive => 1);
        $self->size_range(sensitive => 1);
    }
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
