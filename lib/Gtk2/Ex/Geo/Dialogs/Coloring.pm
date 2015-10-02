package Gtk2::Ex::Geo::Dialogs::Coloring;

use strict;
use warnings;
use locale;
use Carp;
use Graphics::ColorUtils qw /:all/;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw /:all/;
use Gtk2::Ex::Geo::Style;

use base qw(Gtk2::Ex::Geo::Dialog);

use vars qw/$MAX_INT $MAX_REAL $COLOR_CELL_SIZE/;

$MAX_INT = 999999;
$MAX_REAL = 999999999.99;
$COLOR_CELL_SIZE = 20;

sub open {
    my ($self) = @_;
    my $palette = $self->{model};

    my $boot = $self->bootstrap('coloring_dialog', 
                                "Coloring for ".$palette->{style}->{layer}->name.".$palette->{style}->{property}");
    if ($boot) {
        $self->palette_type('boot');
        $self->property_name('boot');
        $self->property_value_range('boot');
        $self->hue('boot');
        $self->border_color('boot');
        $self->color_editor('boot');
        $self->palette_editor('boot');
        $self->palette_manager('boot');
        $self->dialog_manager('boot');
    }

    # back up data
    $self->{model_backup} = $palette->clone();
    $self->palette_type('reset');

}

# view: setup and accessors

sub palette_type {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->setup_combo('palette_type_combobox');
        $self->get_widget('palette_type_combobox')->signal_connect(changed => \&palette_type_changed, $self);
    } elsif (defined $key && $key eq 'reset') {
        $self->refill_combo('palette_type_combobox',
                            [$self->{model}->{style}->{layer}->palette_types],
                            $self->{model}->readable_class_name);
    }
}

sub property_name {
    my ($self, $name, $x) = @_;
    if (defined $name && $name eq 'boot') {
        $self->setup_combo('color_property_combobox');
        $self->get_widget('color_property_combobox')->signal_connect(changed => \&property_name_changed, $self);
    } elsif (defined $name && $name eq 'sensitive') {
        for my $w (qw/color_property_label color_property_combobox/) 
        {
            $self->get_widget($w)->set_sensitive($x);
        }
    } elsif (defined $name) {
        $self->refill_combo('color_property_combobox', $name, $x);
    } else {
        my $name = $self->get_value_from_combo('color_property_combobox');
        return ($name);
    }
}

sub property_value_range {
    my ($self, $min, $max) = @_;
    if (defined $min && $min eq 'boot') {
        $self->get_widget('color_property_value_range_button')->signal_connect(clicked => \&fill_property_value_range, $self);
        $self->get_widget('property_value_min_entry')->signal_connect(changed => \&property_value_range_changed, $self);
        $self->get_widget('property_value_max_entry')->signal_connect(changed => \&property_value_range_changed, $self);
    } elsif (defined $min && $min eq 'sensitive') {
        for my $w (qw/property_value_label2 property_value_min_entry 
                      property_value_label3 property_value_max_entry color_property_value_range_button/) 
        {
            $self->get_widget($w)->set_sensitive($max);
        }
    } elsif (defined $max) {
        $self->get_widget('property_value_min_entry')->set_text($min);
        $self->get_widget('property_value_max_entry')->set_text($max);
    } else {
        $min = POSIX::strtod($self->get_widget('property_value_min_entry')->get_text);
        $max = POSIX::strtod($self->get_widget('property_value_max_entry')->get_text);
        return ($min, $max);
    }
}

sub hue {
    my ($self, $min, $max, $dir) = @_;
    if (defined $min && $min eq 'boot') {
        $self->setup_combo('hue_range_combobox');
        $self->refill_combo('hue_range_combobox', ['down to', 'up to']);
        $self->get_widget('min_hue_button')->signal_connect(clicked => \&set_hue_range_min, $self);
        $self->get_widget('max_hue_button')->signal_connect(clicked => \&set_hue_range_max, $self);
        $self->get_widget('hue_range_combobox')->signal_connect(changed => \&hue_changed, $self);
    } elsif (defined $min && $min eq 'sensitive') {
        for my $w (qw/rainbow_label min_hue_label min_hue_button max_hue_label max_hue_button hue_range_combobox/) {
            $self->get_widget($w)->set_sensitive($max);
        }
    } elsif (defined $dir) {
        $self->get_widget('min_hue_label')->set_text($min);
        $self->get_widget('max_hue_label')->set_text($max);
        my $combo = $self->get_widget('hue_range_combobox');
        $combo->set_active($dir > 0 ? 0 : 1);
    } else {
        $min = POSIX::strtod($self->get_widget('min_hue_label')->get_text);
        $max = POSIX::strtod($self->get_widget('max_hue_label')->get_text);
        $dir = $self->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1; # up is 1, down is -1
        return ($min, $max, $dir);
    }
}

sub border_color {
    my ($self, $add, $color) = @_;
    if (defined $add && $add eq 'boot') {
        $self->get_widget('border_color_button')->signal_connect(clicked => \&border_color_dialog, $self);
    } elsif (defined $add && $add eq 'sensitive') {
        for my $w (qw/border_color_checkbutton border_color_label border_color_button/) {
            $self->get_widget($w)->set_sensitive($color);
        }
    } elsif (defined $add) {
        $self->get_widget('border_color_checkbutton')->set_active($add);
        $self->get_widget('border_color_label')->set_text("@$color");
    } else {
        my @color = split(/ /, $self->get_widget('border_color_label')->get_text);
        my $add = $self->get_widget('border_color_checkbutton')->get_active();
        return ($add, \@color);
    }
}

sub color_editor {
    my ($self, $key, $value, $data) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('edit_color_button')->signal_connect(clicked => \&edit_color, $self);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw/edit_label edit_color_button/) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

sub palette_editor {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('edit_color_button')->signal_connect(clicked => \&edit_color, $self);
        $self->get_widget('delete_color_button')->signal_connect(clicked => \&delete_color, $self);
        $self->get_widget('add_color_button')->signal_connect(clicked => \&add_color, $self);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw/edit_label edit_color_button delete_color_button add_color_button/) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

sub palette_manager {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('copy_palette_button')->signal_connect(clicked => \&copy_palette, $self);
        $self->get_widget('open_palette_button')->signal_connect(clicked => \&open_palette, $self);
        $self->get_widget('save_palette_button')->signal_connect(clicked => \&save_palette, $self);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw/manage_label copy_palette_button open_palette_button save_palette_button/) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

sub dialog_manager {
    my ($self, $key, $value) = @_;
    if (defined $key && $key eq 'boot') {
        $self->get_widget('coloring_apply_button')->signal_connect(clicked => \&apply, [$self, 0]);
        $self->get_widget('coloring_cancel_button')->signal_connect(clicked => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('coloring_dialog')->signal_connect(delete_event => \&Gtk2::Ex::Geo::Dialog::cancel, $self);
        $self->get_widget('coloring_ok_button')->signal_connect(clicked => \&apply, [$self, 1]);
    } elsif (defined $key && $key eq 'sensitive') {
        for my $w (qw//) {
            $self->get_widget($w)->set_sensitive($value);
        }
    }
}

# controller: callbacks for edits

sub palette_type_changed {
    my ($combo, $self) = @_;
    my $palette = $self->{model};
    
    my $palette_type = $self->get_value_from_combo($combo);
    if (!$palette->readable_class_name || $palette->readable_class_name ne $palette_type) {
        my $style = $palette->{style};
        $palette = Gtk2::Ex::Geo::ColorPalette->new( self => $palette,
                                                     readable_class_name => $palette_type,
                                                     style => $style );
        my $treeview = $self->get_widget('coloring_treeview');
        $palette->set_color_view($treeview);
    }

    my $property_name = $palette->property();
    my @properties;
    my $properties = $palette->{style}->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $property = $properties->{$name};
        next unless $property->{Type};
        my $ok = $palette->valid_property_type($property->{Type});
        next unless $ok;
        push @properties, $name;
    }

    $self->property_name(\@properties, $property_name);

    my $output_is_hue = $palette->output_is_hue;
    if ($output_is_hue) {
        my @range = $palette->hue_range;
        $self->hue(@range);
    }

    $palette->prepare_model;

    my @color = $palette->{style}->border_color;
    $self->border_color(@color > 0, \@color);

    $self->color_editor(sensitive => 0);
    $self->palette_editor(sensitive => 0);
    $self->palette_manager(sensitive => 0);
    $self->property_name(sensitive => 0);
    $self->property_value_range(sensitive => 0);
    $self->hue(sensitive => 0);
    $self->border_color(sensitive => 0);

    if ($palette->valid_property_type('Integer')) { # supports properties
        $self->property_name(sensitive => 1);
        $self->property_value_range(sensitive => 1);
    }
    
    if ($output_is_hue) {
        $self->hue(sensitive => 1);
    }
    
    if (!$palette->valid_property_type('Integer')) { # single color
        $self->color_editor(sensitive => 1);
    } elsif ($property_name) {
        $self->property_value_range(sensitive => 1);
    }
    
    if ($palette->is_table_like) {
        $self->palette_editor(sensitive => 1);
        $self->palette_manager(sensitive => 1);
    }

    if ($palette->{style}->include_border) {
        $self->border_color(sensitive => 1);
    }

}

sub property_name_changed {
    my ($combo, $self) = @_;
    my $palette = $self->{model};
    my $property_name = $self->property_name;
    if (defined $property_name && $property_name ne '') {
        my $properties = $palette->{style}->{layer}->schema()->{Properties};
        $palette->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $palette->property(undef);
    }
    $self->property_value_range('', '');
    $palette->prepare_model;
}

sub property_value_range_changed {
    my ($entry, $self) = @_;
    my $palette = $self->{model};
    my ($min, $max) = $self->property_value_range;
    $palette->value_range($min, $max);
    $palette->update_model unless $palette->is_table_like;
}

sub hue_changed {
    my (undef, $self) = @_;
    my $palette = $self->{model};
    return unless $palette->output_is_hue;
    my ($min, $max, $dir) = $self->hue;
    $palette->hue_range($min, $max, $dir);
    $palette->update_model;
}

# button callbacks

sub apply {
    my ($self, $close) = @{$_[1]};
    # border color is still a bit to do, it *should* be implemented as a 2nd style
    my ($add, $color) = $self->border_color;
    @$color = () unless $add;
    $self->{model}->{style}->border_color(@$color);
    $self->SUPER::apply($close);
}

sub copy_palette {
    my ($button, $self) = @_;
    my $palette = $self->{model};

    my $glade = $self->{glue}->get_dialog('coloring_from_dialog');
    my $dialog = $glade->get_widget('coloring_from_dialog');
    $dialog->set_title("Get palette from");
    my $treeview = $glade->get_widget('coloring_from_treeview');
    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }
    my $model = Gtk2::TreeStore->new(qw/Glib::String Glib::String/);
    $treeview->set_model($model);
    my $i = 0;
    for my $column ('Layer', 'Property') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    my @properties;
    for my $layer (@{$self->{glue}->{overlay}->{layers}}) {
        my $properties = $layer->schema()->{Properties};
        for my $name (sort keys %$properties) {
            next if $layer eq $palette->{style}->{layer} && $name eq $palette->property;
            push @properties, [$layer->name(), $name];
            $model->set($model->append(undef), 0, $layer->name(), 1, $name);
        }
    }
    $dialog->show_all;
    $dialog->present;
    my $response = $dialog->run;
    if ($response eq 'ok') {
	my @sel = $treeview->get_selection->get_selected_rows;
	if (@sel) {
	    my $i;
            $i = $sel[0]->to_string;
	    my $layer = $self->{glue}->{overlay}->get_layer_by_name($properties[$i]->[0]);
            #$palette->clone();
            # update the whole view: palette type, property
            #$palette->prepare_model;
	}
    }
    $dialog->destroy;
}

sub open_palette {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my $filename = Gtk2::Ex::Geo::Dialogs::file_chooser("Open palette", 'open');
    if ($filename) {
        $palette->open($filename);
        $palette->update_model;
    }
}

sub save_palette {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my $filename = Gtk2::Ex::Geo::Dialogs::file_chooser("Save palette as", 'save');
    if ($filename) {
        $palette->save_as($filename);
    }
}

sub edit_color {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my $selection = $palette->{color_view}->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;
    my $i = $selected[0]->to_string;
    my $value = $palette->property_value_at($i);
    my @color = $palette->color($value);
    my $d = Gtk2::ColorSelectionDialog->new('Choose a color.');
    my $s = $d->colorsel;
    $s->set_has_opacity_control(1);
    my $c = Gtk2::Gdk::Color->new($color[0]*257, $color[1]*257, $color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    my $ok = $d->run eq 'ok';
    if ($ok) {
	$d->destroy;
	$c = $s->get_current_color;
	@color = (int($c->red/257+0.5),int($c->green/257+0.5),int($c->blue/257+0.5));
	$color[3] = int($s->get_current_alpha()/257+0.5);
        for my $selected (@selected) {
            my $i = $selected->to_string;
            my $value = $palette->property_value_at($i);
            $palette->color($value, @color);
        } 
    } else {
	$d->destroy;
    }
    for my $selected (@selected) {
	$selection->select_path($selected);
    }
    $palette->update_model if $ok;
}

sub delete_color {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my $selection = $palette->{color_view}->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;
    my @to_remove;
    for my $selected (@selected) {
        my $i = $selected->to_string;
        push @to_remove, $palette->property_value_at($i);
    } 
    for my $value (@to_remove) {
        $palette->remove_color_at($value);
    }
    $palette->update_model;
}

sub add_color {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    $palette->add_color($palette->new_property_value, 0, 0, 0, 255);
    $palette->update_model;
}

sub run_hue_select {
    my ($self, $hint, @color) = @_;
    my $color_chooser = Gtk2::ColorSelectionDialog->new("Choose $hint hue.");
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    $s->set_current_color(Gtk2::Gdk::Color->new($color[0]*257, $color[1]*257, $color[2]*257));
    if ($color_chooser->run eq 'ok') {
	my $c = $s->get_current_color;
	my ($hue) = rgb2hsv($c->red/257, $c->green/257, $c->blue/257);
        $color_chooser->destroy;
        return int($hue+0.5);
    }
    $color_chooser->destroy;
}

sub set_hue_range_min {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my ($min, $max, $dir) = $self->hue();
    my @color = hsv2rgb($min, 1, 1);
    my $hue = $self->run_hue_select('minimum', @color);
    if ($hue) {
        $self->hue($hue, $max, $dir);
        hue_changed(undef, $self);
    }
}

sub set_hue_range_max {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my ($min, $max, $dir) = $self->hue();
    my @color = hsv2rgb($max, 1, 1);
    my $hue = $self->run_hue_select('maximum', @color);
    if ($hue) {
        $self->hue($min, $hue, $dir);
        hue_changed(undef, $self);
    }
}

sub border_color_dialog {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my ($add, $color) = $self->border_color;
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the border lines in '.$palette->name);
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color->[0]*257, $color->[1]*257, $color->[2]*257);
    $s->set_current_color($c);
    #$s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	$color = [int($c->red/257+0.5), int($c->green/257+0.5), int($c->blue/257+0.5)];
	#$color[3] = int($s->get_current_alpha()/257);
        $self->border_color(1, $color);
    }
    $color_chooser->destroy;
}

sub fill_property_value_range {
    my ($button, $self) = @_;
    my $palette = $self->{model};
    my @range;
    my $property = $palette->property;
    eval {
	@range = $palette->{style}->{layer}->value_range($property);
    };
    if ($@) {
	$self->{glue}->message("$@");
	return;
    }
    $palette->value_range(@range);
    $range[0] = '' unless defined $range[0];
    $range[1] = '' unless defined $range[1];
    $self->property_value_range(@range);
    $palette->update_model unless $palette->is_table_like;
}

1;
