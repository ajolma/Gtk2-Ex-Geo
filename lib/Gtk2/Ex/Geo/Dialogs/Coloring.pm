package Gtk2::Ex::Geo::Dialogs::Coloring;

use strict;
use warnings;
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
	     color_legend_button => [clicked => \&make_color_legend, $style],

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
	my $combo = $dialog->get_widget('palette_type_combobox');
	my $model = $combo->get_model;
	$model->clear;
	for my $type ($style->{layer}->palette_types()) {
	    $model->set($model->append, 0, $type);
	}

	$combo = $dialog->get_widget('hue_range_combobox');
	$model = $combo->get_model;
	$model->clear;
	for my $type ('up to', 'down to') {
	    $model->set($model->append, 0, $type);
	}
    }

    # back up data

    $style->{backup} = $style->clone();

    # set up the controllers

    my @range = $style->hue_range;

    $dialog->get_widget('min_hue_label')->set_text($range[0]);
    $dialog->get_widget('max_hue_label')->set_text($range[1]);

    my $palette_type = $style->palette_type;
    my $combo = $dialog->get_widget('palette_type_combobox');
    my $i = 0;
    for my $type ($style->{layer}->palette_types()) {
	$combo->set_active($i), last if $type eq $palette_type;
	$i++;
    }

    $combo = $dialog->get_widget('hue_range_combobox');
    $combo->set_active($range[2] > 0 ? 0 : 1);

    fill_color_property_combo($style);
    @range = $style->color_property_value_range;
    $dialog->get_widget('property_value_min_entry')->set_text($range[0]);
    $dialog->get_widget('property_value_max_entry')->set_text($range[1]);

    my @color = $style->border_color;
    $dialog->get_widget('border_color_checkbutton')->set_active(@color > 0);
    $dialog->get_widget('border_color_label')->set_text("@color");

    fill_coloring_treeview($style);
    return $dialog->get_widget('coloring_dialog');
}

# set ups

sub fill_color_property_combo {
    my ($style) = @_;
    my $palette_type = $style->palette_type;
    my $combo = $style->{coloring_dialog}->get_widget('color_property_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my $i = 0;
    my $active;
    my $color_property = $style->color_property();
    $color_property = '' unless defined $color_property;
    my $properties = $style->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $property = $properties->{$name};
	next unless $property->{Type};
        my $ok = (
            ($property->{Type} eq 'String' and
             Gtk2::Ex::Geo::Layer::palette_type_supports_string_keys($palette_type)) or
            ($property->{Type} eq 'Integer' and
             Gtk2::Ex::Geo::Layer::palette_type_supports_integer_keys($palette_type)) or
            ($property->{Type} eq 'Real' and
             Gtk2::Ex::Geo::Layer::palette_type_supports_real_keys($palette_type)));
        next unless $ok;
	$model->set($model->append, 0, $name);
	$active = $i if $name eq $color_property;
	$i++;
    }
    $active = 0 unless defined $active;
    $combo->set_active($active);
}

# callbacks for edits

sub palette_type_changed {
    my ($combo, $style) = @_;
    my $dialog = $style->{coloring_dialog};
    my $palette_type = get_value_from_combo($dialog, 'palette_type_combobox');
    $style->palette_type($palette_type);

    fill_color_property_combo($style);
    
    my %activate;

    my $string_keys = Gtk2::Ex::Geo::Layer::palette_type_supports_string_keys($palette_type);
    my $int_keys = Gtk2::Ex::Geo::Layer::palette_type_supports_integer_keys($palette_type);
    my $real_keys = Gtk2::Ex::Geo::Layer::palette_type_supports_real_keys($palette_type);
    my $finite_keys = Gtk2::Ex::Geo::Layer::palette_type_has_finite_keys($palette_type);
    my $hues = Gtk2::Ex::Geo::Layer::palette_type_output_is_hue($palette_type);
    my $keys = ($string_keys or $int_keys or $real_keys);

    for (qw/coloring_treeview color_property_label color_property_combobox 
            property_value_label2 property_value_min_entry 
            property_value_label3 property_value_max_entry color_property_value_range_button
            color_legend_button
            rainbow_label
            min_hue_label min_hue_button max_hue_label max_hue_button hue_range_combobox
            border_color_checkbutton border_color_label border_color_button
            edit_label edit_color_button delete_color_button add_color_button
            manage_label copy_palette_button open_palette_button save_palette_button/) 
    {
        $activate{$_} = 0;
    }

    if ($keys) {
	for (qw/color_property_label color_property_combobox/) {
            $activate{$_} = 1;
	}
    }
    
    if ($hues) {
	for (qw/rainbow_label
                min_hue_label min_hue_button max_hue_label max_hue_button 
                hue_range_combobox/) {
            $activate{$_} = 1;
	}
    }
    
    if (!$keys) {
	for (qw/coloring_treeview edit_label edit_color_button/) {
            $activate{$_} = 1;
	}
    } elsif (!$finite_keys) {
	for (qw/coloring_treeview property_value_label2 property_value_min_entry 
                property_value_label3 property_value_max_entry color_property_value_range_button
                color_legend_button/) {
            $activate{$_} = 1;
	}
    } else {
	for (qw/coloring_treeview 
                manage_label copy_palette_button open_palette_button save_palette_button 
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
    return unless $property; # model is cleared
    $style->color_property($property);
    my $palette = $style->palette_type;
    if (($palette eq 'Color bins' or $palette eq 'Color table') and 
	$style->{current_coloring_type} ne current_coloring_type($style)) {
	create_coloring_treeview($style);
    }
}

sub color_property_value_range_changed {
    my ($entry, $style) = @_;
    my $d = $style->{coloring_dialog};
    my $min = get_number_from_entry($d->get_widget('property_value_min_entry'));
    my $max = get_number_from_entry($d->get_widget('property_value_max_entry'));
    $style->color_property_value_range($min, $max);
}

sub hue_changed {
    my ($combo, $style) = @_;
    my $d = $style->{coloring_dialog};
    my $min = get_number_from_entry($d->get_widget('min_hue_label'));
    my $max = get_number_from_entry($d->get_widget('max_hue_label'));
    my $dir = $d->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1; # up is 1, down is -1
    $style->hue_range($min, $max, $dir);
    create_coloring_treeview($style);
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
	my $palette_type = $style->palette_type;
	if ($palette_type eq 'Color table') {
	    $style->color_table($table);
	} elsif ($palette_type eq 'Color bins') {
	    $style->color_bins($table);
	}
	fill_coloring_treeview($style);
    }
}

sub open_palette {
    my ($button, $style) = @_;
    my $palette_type = $style->palette_type;
    my $filename = file_chooser("Select a $palette_type file", 'open');
    if ($filename) {
	if ($palette_type eq 'Color table') {
	    eval {
		$style->color_table($filename);
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		$style->color_bins($filename);
	    }
	}
	if ($@) {
	    $style->{layer}->{glue}->message("$@");
	} else {
	    fill_coloring_treeview($style);
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
    my $palette_type = $style->palette_type;
    my $treeview = $style->{coloring_dialog}->get_widget('coloring_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;

    my $i = $selected[0]->to_string;
    my $x;
    my @color;
    if ($palette_type eq 'Single color') {
	@color = $style->color;
    } else {
	@color = $style->color($i);
	$x = shift @color;
	@color = @color;
    }
	    
    my $d = Gtk2::ColorSelectionDialog->new('Choose color for selected entries');
    my $s = $d->colorsel;
	    
    $s->set_has_opacity_control(1);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    
    if ($d->run eq 'ok') {
	$d->destroy;
	$c = $s->get_current_color;
	@color = (int($c->red/257+0.5),int($c->green/257+0.5),int($c->blue/257+0.5));
	$color[3] = int($s->get_current_alpha()/257+0.5);

	if ($palette_type eq 'Single color') {
	    $style->color(@color);
	} else {
	    for my $selected (@selected) {
		my $i = $selected->to_string;
		$style->color($i, $x, @color);
	    } 
	}
	fill_coloring_treeview($style);
    } else {
	$d->destroy;
    }
    
    for my $selected (@selected) {
	$selection->select_path($selected);
    }
}

sub delete_color {
    my ($button, $style) = @_;
    my $palette_type = $style->palette_type;
    my $table = $palette_type eq 'Color table' ?
	$style->color_table() : 
	( $palette_type eq 'Color bins' ? $style->color_bins() : undef );
    return unless $table and @$table;
    my $treeview = $style->{coloring_dialog}->get_widget('coloring_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $model = $treeview->get_model;
    return unless $model;
    my $at;
    for my $selected (@selected) {
	$at = $selected->to_string;
	my $iter = $model->get_iter_from_string($at);
	$model->remove($iter);
	$style->remove_color($at);
    }
    #$at--;
    $at = 0 if $at < 0;
    $at = $#$table if $at > $#$table;
    return if $at < 0;
    $treeview->set_cursor(Gtk2::TreePath->new($at));
}

sub add_color {
    my ($button, $style) = @_;
    my $treeview = $style->{coloring_dialog}->get_widget('coloring_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $index = $selected[0]->to_string+1 if @selected;
    my $model = $treeview->get_model;
    return unless $model;
    my $palette_type = $style->palette_type;
    my @color = (255, 255, 255, 255);
    my $table = $palette_type eq 'Color table' ? $style->color_table : $style->color_bins;
    $index = @$table unless $index;
    my $x;
    if (@$table) {
	if ($palette_type eq 'Color table') {
	    if (current_coloring_type($style) eq 'Int') {
		if ($index > 0) {
		    $x = $table->[$index-1]->[0]+1;
		    while ($index < @$table and $x == $table->[$index]->[0]) {
			$x++;
			$index++;
		    }
		} else {
		    $x = 0;
		}
	    } else {
		$x = 'change this';
	    }
	} elsif ($palette_type eq 'Color bins') {
	    if (@$table == 1 or $index <= 0 or $index > $#$table) {
		$x = $table->[$#$table]->[0] + 1;
	    } else {
		if (current_coloring_type($style) eq 'Int') {
		    $x = $table->[$index-1]->[0]+1;
		    while ($index < @$table and $x == $table->[$index]->[0]) {
			$x++;
			$index++;
		    } 
		} else {
		    $x = ($table->[$index-1]->[0] + $table->[$index]->[0])/2;
		}
	    }
	}
    } else {
	if (current_coloring_type($style) eq 'String') {
	    $x = 'change this';
	} else {
	    $x = 0;
	}
	$index = 0;
    }
    $style->add_color($index, $x, @color);
    my $iter = $model->insert(undef, $index);
    set_color($model, $iter, $x, @color);
    $treeview->set_cursor(Gtk2::TreePath->new($index));
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
	@range = $style->value_range($property);
    };
    if ($@) {
	$style->{layer}->{glue}->message("$@");
	return;
    }
    my $dialog = $style->{coloring_dialog};
    $dialog->get_widget('property_value_min_entry')->set_text($range[0]) if defined $range[0];
    $dialog->get_widget('property_value_max_entry')->set_text($range[1]) if defined $range[1];
}

sub make_color_legend {
    my ($button, $style) = @_;
    put_scale_in_treeview($style);
}

# color treeview subs

sub cell_in_coloring_treeview_changed {
    my ($cell, $path, $new_value, $data) = @_;
    my ($style, $column) = @$data;
    my $palette_type = $style->palette_type;
    my @color;
    if ($palette_type eq 'Single color') {
	@color = $style->color();
    } else {
	@color = $style->color($path);
    }
    $color[$column] = $new_value;
    if ($palette_type eq 'Single color') {
	$style->color(@color);
    } else {
	$style->color($path, @color);
    }
    fill_coloring_treeview($style);
}

sub create_coloring_treeview {
    my ($style) = @_;

    my $palette_type = $style->palette_type;
    my $treeview = $style->{coloring_dialog}->get_widget('coloring_treeview');
    
    if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	put_scale_in_treeview($style);
	return 1;
    }
    
    my $model = $treeview->get_model;
    $model->clear if $model;
    my $type = $style->{current_coloring_type} = current_coloring_type($style);
    if ($palette_type eq 'Single color') {
	$model = Gtk2::TreeStore->new(
	    qw/Gtk2::Gdk::Pixbuf Glib::Int Glib::Int Glib::Int Glib::Int/);
    } elsif ($palette_type eq 'Color table') {
	return unless $type;
	$model = Gtk2::TreeStore->new(
	    "Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
    } elsif ($palette_type eq 'Color bins') {
	return unless $type;
	$model = Gtk2::TreeStore->new(
	    "Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
    }
    $treeview->set_model($model);
    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }

    my $i = 0;
    my $cell;
    my $column;

    if ($palette_type ne 'Single color') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&cell_in_coloring_treeview_changed, [$style, $i]);
	$column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
	$treeview->append_column($column);
    }

    $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($COLOR_CELL_SIZE-2,$COLOR_CELL_SIZE-2);
    $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $treeview->append_column($column);

    for my $c ('red','green','blue','alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&cell_in_coloring_treeview_changed, [$style, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$treeview->append_column($column);
    }
    $treeview->get_selection->set_mode('multiple');
    fill_coloring_treeview($style);
    return 1;
}

sub current_coloring_type {
    my ($style) = @_;
    my $property = $style->color_property;
    return '' unless defined $property;
    my $properties = $style->{layer}->schema->{Properties};
    $property = $properties->{$property};
    return '' unless $property;
    return 'Int' if $property->{Type} eq 'Integer';
    return 'Double' if $property->{Type} eq 'Real';
    return 'String' if $property->{Type} eq 'String';
    return '';
}

sub fill_coloring_treeview {
    my ($style) = @_;

    my $palette_type = $style->palette_type;
    my $treeview = $style->{coloring_dialog}->get_widget('coloring_treeview');
    my $model = $treeview->get_model;
    return unless $model;
    $model->clear;

    if ($palette_type eq 'Single color') {
	
	my $iter = $model->append(undef);
	set_color($model,$iter, undef, $style->color());

    } elsif ($palette_type eq 'Color table') {

	my $table = $style->color_table();

	for my $color (@$table) {
	    my $iter = $model->append(undef);
	    set_color($model, $iter, @$color);
	}
	
    } elsif ($palette_type eq 'Color bins') {

	my $table = $style->color_bins();

	for my $color (@$table) {
	    my $iter = $model->append(undef);
	    set_color($model, $iter, @$color);
	}
	
    }

}

sub set_color {
    my ($model, $iter, $value, @color) = @_;
    my @set = ($iter);
    my $j = 0;
    push @set, ($j++, $value) if defined $value;
    my $pb = Gtk2::Gdk::Pixbuf->new('rgb',0,8,$COLOR_CELL_SIZE,$COLOR_CELL_SIZE);
    $pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);
    push @set, ($j++, $pb);
    for my $k (0..3) {
	push @set, ($j++, $color[$k]);
    }
    $model->set(@set);
}


sub put_scale_in_treeview {
    my ($style) = @_;
    my $palette_type = $style->palette_type;
    my $dialog = $style->{coloring_dialog};
    my $treeview = $dialog->get_widget('coloring_treeview');

    my $model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Double/);
    $treeview->set_model($model);
    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }

    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($COLOR_CELL_SIZE-2, $COLOR_CELL_SIZE-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $treeview->append_column($column);

    $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 0);
    $column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
    $treeview->append_column($column);

    my ($min, $max) = $style->color_property_value_range;
    return if $min eq '' or $max eq '';
    my $delta = ($max-$min)/14;
    return if $delta <= 0;

    my ($hue_min, $hue_max, $hue_dir) = $style->hue_range;
    if ($hue_dir == 1) {
	$hue_max += 360 if $hue_max < $hue_min;
    } else {
	$hue_max -= 360 if $hue_max > $hue_min;
    }
    my @range = $style->color_property_value_range;
    my $invert_palette = $range[1] < $range[0];
    
    my $x = $max;
    for my $i (1..15) {
	my $iter = $model->append(undef);

	my @set = ($iter);

	my ($h,$s,$v);
	my $alpha = 255;
	if ($palette_type eq 'Grayscale') {
            $h = 0;
            $s = 0;
            $v = ($x - $min)/($max - $min);
            $v = 1 - $v if $invert_palette;
	} else {
	    $h = int($hue_min + ($x - $min)/($max-$min) * ($hue_max-$hue_min) + 0.5);
	    $h -= 360 if $h > 360;
	    $h += 360 if $h < 0;
	    $s = 1;
	    $v = 1;
	}
	
        my $pb = Gtk2::Gdk::Pixbuf->new('rgb', 0, 8, $COLOR_CELL_SIZE, $COLOR_CELL_SIZE);
	my @color = hsv2rgb($h, $s, $v);
        $pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);

	my $j = 0;
	push @set, ($j++, $pb);
	push @set, ($j++, $x);
	$model->set(@set);
	$x -= $delta;
	$x = $min if $x < $min;
    }
}

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
	    my $i = $sel[0]->to_string if @sel;
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
