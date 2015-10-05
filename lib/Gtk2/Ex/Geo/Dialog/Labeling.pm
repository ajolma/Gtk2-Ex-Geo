package Gtk2::Ex::Geo::Dialogs::Labeling;

use strict;
use warnings;
use locale;
use Carp;
use Glib qw/TRUE FALSE/;

use base qw(Gtk2::Ex::Geo::Dialog);

sub open {
    my ($self) = @_;
    my $context = $self->{model}->{style}->{layer}->name.'.'.$self->{model}->{style}->{property};
    my $boot = $self->bootstrap('labeling_dialog', "Labels for $context.");

    if ($boot) {
        $self->property_name('boot');
        $self->font_properties('boot');
        $self->labeling_manager('boot');
        $self->dialog_manager('boot');
    }

    # reset view

    $self->use_labels(defined $self->{model}->property);

}

# view: setup and accessors ($self->{model} should not be used here)

sub use_labels {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->get_widget('use_labels_checkbutton')->signal_connect(toggled => \&use_labels_changed, $self);
    } elsif (defined $name && $name eq 'set up') {
    }  elsif (defined $name && $name eq 'sensitive') {
    } elsif (defined $name) {
        $self->get_widget('use_labels_checkbutton')->set_active($name);
    } else {
        return $self->get_widget('use_labels_checkbutton')->get_active;
    }
}

sub property_name {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('labels_field_combobox');
        $self->get_widget('labels_field_combobox')->signal_connect(changed => \&property_name_changed, $self);
    }  elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/labels_field_combobox/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        $self->refill_combo('labels_field_combobox', $name, $x);
    } else {
        my $name = $self->get_value_from_combo('symbols_field_combobox');
        return ($name);
    }
}

sub font_properties {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->get_widget('labels_font_button')->signal_connect(clicked => \&select_font, $self);
        $self->get_widget('labels_color_button')->signal_connect(clicked => \&select_font_color, $self);
    } elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/labels_font_label labels_font_button labels_color_label labels_color_button/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        $self->get_widget('labels_font_label')->set_text($name->{name});
        $self->get_widget('labels_color_label')->set_text("@{$name->{color}}");
    } else {
        $x->{name}->{font} = $self->get_widget('labels_font_label')->get_text;
        $x->{color} = [split / /, $self->get_widget('labels_color_label')->get_text];
        return $x;
    }
}

sub labeling_manager {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('labels_placement_combobox');
        $self->refill_combo('labels_placement_combobox', [$self->{model}->placements], $self->{model}->placement);
    } elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/labels_placement_combobox labels_min_size_entry labels_incremental_checkbutton/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        $self->get_widget('labels_min_size_entry')->set_text($name->{min_size});
        $self->get_widget('labels_incremental_checkbutton')->set_active($name->{incremental});
    } else {
        $x->{min_size} = $self->get_widget('labels_min_size_entry')->get_text;
        $x->{incremental} = $self->get_widget('labels_incremental_checkbutton')->get_active;
        return $x;
    }
}

sub dialog_manager {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('apply_labels_button')->signal_connect(clicked => \&apply, [$self, 0]);
        $self->get_widget('cancel_labels_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('labeling_dialog')->signal_connect(delete_event => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('ok_labels_button')->signal_connect(clicked => \&apply, [$self, 1]);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw//) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

# controller: callbacks for edits

sub use_labels_changed {
    my ($checkbutton, $self) = @_;
    $self->property_name(sensitive => $checkbutton->get_active);
    $self->font_properties(sensitive => $checkbutton->get_active);
    $self->labeling_manager(sensitive => $checkbutton->get_active);
    if ($checkbutton->get_active) {
        my $property_name = $self->{model}->property();
        my @properties = ();
        my $properties = $self->{model}->{style}->{layer}->schema()->{Properties};
        for my $name (sort keys %$properties) {
            my $property = $properties->{$name};
            next unless $property->{Type};
            my $ok = $self->{model}->valid_property_type($property->{Type});
            next unless $ok;
            push @properties, $name;
        }
        $self->property_name(\@properties, $property_name);
    }
}

sub property_name_changed {
    my ($combo, $self) = @_;
    my $property_name = $self->property_name;
    if (defined $property_name && $property_name ne '') {
        my $properties = $self->{model}->{style}->{layer}->schema()->{Properties};
        $self->{model}->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $self->{model}->property(undef);
    }
}

sub apply {
    my ($self, $close) = @{$_[1]};
    $self->{model}->property();
    $self->{model}->font_properties($self->font_properties);
    $self->{model}->labeling_options($self->labeling_manager);
    $self->SUPER::apply($close);
}

sub select_font {
    my($button, $self) = @_;
    my $font_chooser = Gtk2::FontSelectionDialog->new ("Select font for the labels");
    my $font = $self->{model}->font_properties();
    $font_chooser->set_font_name($font->{name});
    if ($font_chooser->run eq 'ok') {
	$font->{name} = $font_chooser->get_font_name;
	$self->font_properties($font);
        $self->{model}->font_properties($font);
    }
    $font_chooser->destroy;
}

sub select_font_color {
    my($button, $self) = @_;
    my @color = split(/ /, $self->{labels_dialog}->get_widget('labels_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the label font');
    my $s = $color_chooser->colorsel;    
    $s->set_has_opacity_control(1);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	$color[3] = int($s->get_current_alpha()/257);
	$self->{labels_dialog}->get_widget('labels_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

1;
