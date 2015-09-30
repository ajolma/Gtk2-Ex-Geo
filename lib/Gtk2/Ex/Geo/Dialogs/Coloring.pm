package Gtk2::Ex::Geo::Dialogs::Coloring;

use strict;
use warnings;
use locale;
use Carp;
use Graphics::ColorUtils qw /:all/;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw /:all/;
use Gtk2::Ex::Geo::Style;

use vars qw/$MAX_INT $MAX_REAL $COLOR_CELL_SIZE/;

$MAX_INT = 999999;
$MAX_REAL = 999999999.99;
$COLOR_CELL_SIZE = 20;

# open coloring dialog

sub open {
    my ($style) = @_;

    my ($dialog, $boot) = $style->bootstrap_dialog
	('coloring_dialog', "Coloring for ".$style->{layer}->name.".$style->{property}",
	 {
	     coloring_dialog => [delete_event => \&cancel_coloring, $style],
	     color_property_value_range_button => [clicked => \&fill_color_property_value_range, $style],

	     copy_palette_button => [clicked => \&copy_palette, $style],
	     open_palette_button => [clicked => \&open_palette, $style],
	     save_palette_button => [clicked => \&save_palette, $style],

	     edit_color_button => [clicked => \&edit_color, $style],
	     delete_color_button => [clicked => \&delete_color, $style],
	     add_color_button => [clicked => \&add_color, $style],

	     min_hue_button => [clicked => \&set_hue_range, [$style, 'min']],
	     max_hue_button => [clicked => \&set_hue_range, [$style, 'max']],

	     border_color_button => [clicked => \&border_color_dialog, $style],

	     coloring_apply_button => [clicked => \&apply_coloring, [$style, 0]],
	     coloring_cancel_button => [clicked => \&cancel_coloring, $style],
	     coloring_ok_button => [clicked => \&apply_coloring, [$style, 1]],

	     palette_type_combobox => [changed => \&palette_type_changed, $style],
	     color_property_combobox => [changed => \&color_property_changed, $style],

	     property_value_min_entry => [changed => \&color_property_value_range_changed, $style],
	     property_value_max_entry => [changed => \&color_property_value_range_changed, $style],

	     hue_range_combobox => [changed => \&hue_changed, $style],
	     
	 },
	 [qw /palette_type_combobox color_property_combobox hue_range_combobox/]
	);
    if ($boot) {
        refill_combo($dialog, 'hue_range_combobox', ['down to', 'up to']);
    }

    # back up data

    $style->{backup} = $style->clone();

    # set up the controllers

    refill_combo($dialog, 
                 'palette_type_combobox',
                 [$style->{layer}->palette_types()],
                 $style->palette->readable_class_name);

    return $dialog->get_widget('coloring_dialog');
}

# callbacks for edits

sub palette_type_changed {
    my ($combo, $style) = @_;
    my $dialog = $style->{coloring_dialog};
    my $palette_type = get_value_from_combo($dialog, 'palette_type_combobox');
    my $palette = $style->palette;

    if ($palette->readable_class_name ne $palette_type) {
        $palette = Gtk2::Ex::Geo::ColorPalette->new( readable_class_name => $palette_type );
        $style->palette($palette);
    }

    my $property_name = $style->color_property();
    my $property_name_is_ok;
    my @properties;
    my $properties = $style->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $property = $properties->{$name};
	next unless $property->{Type};
        my $ok = (
            ($property->{Type} eq 'String' and $palette->supports_string_keys) or
            ($property->{Type} eq 'Integer' and $palette->supports_integer_keys) or
            ($property->{Type} eq 'Real' and $palette->supports_real_keys));
        next unless $ok;
        push @properties, $name;
        $property_name_is_ok = 1 if defined $property_name && $property_name eq $name;
    }
    undef $property_name unless $property_name_is_ok;
    if (@properties) {
        $property_name = $properties[0] unless $property_name;
        $style->color_property($property_name);
        $palette->key_type($properties->{$property_name}->{Type});
    }

    my $treeview = $style->{coloring_dialog}->get_widget('coloring_treeview');
    $palette->set_mvc($treeview);

    refill_combo($dialog,
                 'color_property_combobox',
                 \@properties,
                 $property_name);

    my $output_is_hue = $palette->output_is_hue;
    if ($output_is_hue) {
        my @range = $palette->hue_range;
        $dialog->get_widget('min_hue_label')->set_text($range[0]);
        $dialog->get_widget('max_hue_label')->set_text($range[1]);
        my $combo = $dialog->get_widget('hue_range_combobox');
        $combo->set_active($range[2] > 0 ? 0 : 1);
    }

    my $finite_keys = $palette->has_finite_keys;
    if (defined $finite_keys and $finite_keys == 0) {
        my @range = $palette->value_range;
        if (defined $range[0] and defined $range[1]) {
            $dialog->get_widget('property_value_min_entry')->set_text($range[0]);
            $dialog->get_widget('property_value_max_entry')->set_text($range[1]);
        }
    }

    $palette->set_up_mvc;

    my @color = $style->border_color;
    $dialog->get_widget('border_color_checkbutton')->set_active(@color > 0);
    $dialog->get_widget('border_color_label')->set_text("@color");

    my %activate;
    my $string_keys = $palette->supports_string_keys;
    my $int_keys = $palette->supports_integer_keys;
    my $real_keys = $palette->supports_real_keys;
    my $keys = ($string_keys or $int_keys or $real_keys);

    for (qw/color_property_label color_property_combobox 
            property_value_label2 property_value_min_entry 
            property_value_label3 property_value_max_entry color_property_value_range_button
            rainbow_label
            min_hue_label min_hue_button max_hue_label max_hue_button hue_range_combobox
            border_color_checkbutton border_color_label border_color_button
            edit_label edit_color_button delete_color_button add_color_button
            manage_label copy_palette_button open_palette_button save_palette_button/) 
    {
        $activate{$_} = 0;
    }

    if ($keys) {
	for (qw/color_property_label color_property_combobox
                property_value_label2 property_value_min_entry 
                property_value_label3 property_value_max_entry color_property_value_range_button/) {
            $activate{$_} = 1;
	}
    }
    
    if ($output_is_hue) {
	for (qw/rainbow_label
                min_hue_label min_hue_button max_hue_label max_hue_button 
                hue_range_combobox/)
        {
            $activate{$_} = 1;
	}
    }
    
    if (!$keys) {
	for (qw/edit_label edit_color_button/) 
        {
            $activate{$_} = 1;
	}
    } elsif (!$finite_keys) {
	for (qw/property_value_label2 property_value_min_entry 
                property_value_label3 property_value_max_entry color_property_value_range_button/) 
        {
            $activate{$_} = 1;
	}
    } else {
	for (qw/manage_label copy_palette_button open_palette_button save_palette_button 
                edit_label edit_color_button delete_color_button add_color_button/) {
            $activate{$_} = 1;
	}
    }

    if ($style->include_border) {
	for (qw/border_color_checkbutton border_color_label border_color_button/) 
        {
            $activate{$_} = 1;
	}
    }

    for my $widget (keys %activate) {
        my $w = $dialog->get_widget($widget);
        print STDERR "Can't find widget $widget.\n" unless $w;
        next unless $w;
        $w->set_sensitive($activate{$widget});
    }

}

sub color_property_changed {
    my ($combo, $style) = @_;
    my $property = get_value_from_combo($style->{coloring_dialog}, 'color_property_combobox');
    return unless $property;
    $style->color_property($property);
    my $properties = $style->{layer}->schema()->{Properties};
    $style->palette->key_type($properties->{$property}->{Type});
}

sub color_property_value_range_changed {
    my ($entry, $style) = @_;
    my $d = $style->{coloring_dialog};
    my $min = POSIX::strtod($d->get_widget('property_value_min_entry')->get_text);
    my $max = POSIX::strtod($d->get_widget('property_value_max_entry')->get_text);
    $style->palette->value_range($min, $max);
}

sub hue_changed {
    my ($combo, $style) = @_;
    my $d = $style->{coloring_dialog};
    return unless $style->palette->output_is_hue;
    my $min = POSIX::strtod($d->get_widget('min_hue_label')->get_text);
    my $max = POSIX::strtod($d->get_widget('max_hue_label')->get_text);
    my $dir = $d->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1; # up is 1, down is -1
    $style->palette->hue_range($min, $max, $dir);
    $style->palette->set_up_mvc;
}

# button callbacks

sub apply_coloring {
    my ($style, $close) = @{$_[1]};
    my @color = split(/ /, $style->{coloring_dialog}->get_widget('border_color_label')->get_text);
    my $has_border = $style->{coloring_dialog}->get_widget('border_color_checkbutton')->get_active();
    @color = () unless $has_border;
    $style->border_color(@color);
    $style->hide_dialog('coloring_dialog') if $close;
    $style->{layer}->{glue}->{overlay}->render;
}

sub cancel_coloring {
    my ($button, $style) = @_;
    $style->restore_from($style->{backup});
    $style->hide_dialog('coloring_dialog');
    $style->{layer}->{glue}->{overlay}->render;
    1;
}

sub copy_palette {
    my ($button, $style) = @_;
    my $table = copy_palette_dialog($style);
    if ($table) {
	my $palette = $style->palette;
	if ($palette eq 'Color table') {
	    $palette->color_table($table);
	} elsif ($palette eq 'Color bins') {
	    $palette->color_bins($table);
	}
	$palette->set_up_mvc;
    }
}

sub open_palette {
    my ($button, $style) = @_;
    my $palette = $style->palette;
    my $filename = file_chooser("Select a $palette file", 'open');
    if ($filename) {
	if ($palette eq 'Color table') {
	    eval {
		$style->color_table($filename);
	    }
	} elsif ($palette eq 'Color bins') {
	    eval {
		$style->color_bins($filename);
	    }
	}
	if ($@) {
	    $style->{layer}->{glue}->message("$@");
	} else {
            $palette->set_up_mvc;
	}
    }
}

sub save_palette {
    my ($button, $style) = @_;
    my $palette_type = $style->palette_type;
    my $filename = file_chooser("Save $palette_type file as", 'save');
    if ($filename) {
	if ($palette_type eq 'Color table') {
	    eval {
		$style->save_color_table($filename); 
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		$style->save_color_bins($filename);
	    }
	}
	if ($@) {
	    $style->{layer}->{glue}->message("$@");
	}
    }
}

sub edit_color {
    my ($button, $style) = @_;
    $style->palette->edit_color;
}

sub delete_color {
    my ($button, $style) = @_;
    $style->palette->delete_color;
}

sub add_color {
    my ($button, $style) = @_;
    my $palette = $style->palette;
    $palette->add_color($palette->new_key, 0, 0, 0, 255);
    $palette->set_up_mvc;
}

sub set_hue_range {
    my ($style, $dir) = @{$_[1]};
    my $dialog = $style->{coloring_dialog};
    my $hue = $dialog->get_widget($dir.'_hue_label')->get_text();
    my @color = hsv2rgb($hue, 1, 1);
    my $color_chooser = Gtk2::ColorSelectionDialog->new("Choose $dir hue for rainbow palette");
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = rgb2hsv($c->red/257, $c->green/257, $c->blue/257);
	$dialog->get_widget($dir.'_hue_label')->set_text(int($color[0]+0.5));
    }
    $color_chooser->destroy;
    hue_changed(undef, $style);
}

sub border_color_dialog {
    my ($button, $style) = @_;
    my $dialog = $style->{coloring_dialog};
    my @color = split(/ /, $dialog->get_widget('border_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the border lines in '.$style->name);
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    #$s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257+0.5),int($c->green/257+0.5),int($c->blue/257+0.5));
	#$color[3] = int($s->get_current_alpha()/257);
	$dialog->get_widget('border_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

sub fill_color_property_value_range {
    my ($button, $style) = @_;
    my @range;
    my $property = $style->color_property;
    eval {
	@range = $style->{layer}->value_range($property);
    };
    if ($@) {
	$style->{layer}->{glue}->message("$@");
	return;
    }
    my $dialog = $style->{coloring_dialog};
    if (@range) {
        $dialog->get_widget('property_value_min_entry')->set_text($range[0]);
        $dialog->get_widget('property_value_max_entry')->set_text($range[1]);
        $range[0] = POSIX::strtod($range[0]);
        $range[1] = POSIX::strtod($range[1]);
        $style->palette->value_range(@range);
    }
}

# color treeview subs

sub copy_palette_dialog {
    my ($style) = @_;

    my $palette_type = $style->palette_type;
    my $dialog = $style->{layer}->{glue}->get_dialog('coloring_from_dialog');
    $dialog->get_widget('coloring_from_dialog')->set_title("Get $palette_type from");
    my $treeview = $dialog->get_widget('coloring_from_treeview');

    my $model = Gtk2::TreeStore->new(qw/Glib::String/);
    $treeview->set_model($model);

    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }

    my $i = 0;
    for my $column ('Layer') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }

    $model->clear;
    my @names;
    for my $layer (@{$style->{layer}->{glue}->{overlay}->{layers}}) {
	next if $layer->name() eq $style->name();
	push @names, $layer->name();
	$model->set ($model->append(undef), 0, $layer->name());
    }

    #$dialog->move(@{$style->{coloring_from_position}}) if $style->{coloring_from_position};
    $dialog->get_widget('coloring_from_dialog')->show_all;
    $dialog->get_widget('coloring_from_dialog')->present;

    my $response = $dialog->get_widget('coloring_from_dialog')->run;

    my $table;

    if ($response eq 'ok') {

	my @sel = $treeview->get_selection->get_selected_rows;
	if (@sel) {
	    my $i;
            $i = $sel[0]->to_string if @sel;
	    my $from_layer = $style->{layer}->{glue}->{overlay}->get_layer_by_name($names[$i]);

	    if ($palette_type eq 'Color table') {
		$table = $from_layer->color_table();
	    } elsif ($palette_type eq 'Color bins') {
		$table = $from_layer->color_bins();
	    }
	}
	
    }

    $dialog->get_widget('coloring_from_dialog')->destroy;

    return $table;
}

1;
