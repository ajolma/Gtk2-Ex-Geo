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
    my ($style) = @_;
    my $palette = $style->palette;

    my ($self, $boot) = Gtk2::Ex::Geo::Dialogs::Coloring->bootstrap
	($palette, 'coloring_dialog', "Coloring for ".$style->{layer}->name.".$style->{property}",
	 {
	     coloring_dialog => [delete_event => \&cancel_coloring, $palette],
	     color_property_value_range_button => [clicked => \&fill_color_property_value_range, $palette],

	     copy_palette_button => [clicked => \&copy_palette, $palette],
	     open_palette_button => [clicked => \&open_palette, $palette],
	     save_palette_button => [clicked => \&save_palette, $palette],

	     edit_color_button => [clicked => \&edit_color, $palette],
	     delete_color_button => [clicked => \&delete_color, $palette],
	     add_color_button => [clicked => \&add_color, $palette],

	     min_hue_button => [clicked => \&set_hue_range, [$palette, 'min']],
	     max_hue_button => [clicked => \&set_hue_range, [$palette, 'max']],

	     border_color_button => [clicked => \&border_color_dialog, $palette],

	     coloring_apply_button => [clicked => \&apply_coloring, [$palette, 0]],
	     coloring_cancel_button => [clicked => \&cancel_coloring, $palette],
	     coloring_ok_button => [clicked => \&apply_coloring, [$palette, 1]],

	     palette_type_combobox => [changed => \&palette_type_changed, $palette],
	     color_property_combobox => [changed => \&color_property_changed, $palette],

	     property_value_min_entry => [changed => \&color_property_value_range_changed, $palette],
	     property_value_max_entry => [changed => \&color_property_value_range_changed, $palette],

	     hue_range_combobox => [changed => \&hue_changed, $palette],
	     
	 },
	 [qw /palette_type_combobox color_property_combobox hue_range_combobox/]
	);
    if ($boot) {
        $palette->{view} = $self;
        $self->refill_combo('hue_range_combobox', ['down to', 'up to']);
    }

    # back up data

    #$palette->{backup} = $palette->clone();

    # set up the controllers

    $self->refill_combo('palette_type_combobox',
                        [$style->{layer}->palette_types()],
                        $palette->readable_class_name);

}

# callbacks for edits

sub palette_type_changed {
    my ($combo, $palette) = @_;
    my $self = $palette->{view};
    
    my $palette_type = $self->get_value_from_combo('palette_type_combobox');
    if ($palette->readable_class_name ne $palette_type) {
        my $style = $palette->{style};
        $palette = Gtk2::Ex::Geo::ColorPalette->new( self => $palette,
                                                     readable_class_name => $palette_type,
                                                     style => $style,
                                                     view => $self );
        my $treeview = $self->get_widget('coloring_treeview');
        $palette->set_color_view($treeview);
    }

    my $property_name = $palette->property();
    my $property_name_is_ok;
    my @properties;
    my $properties = $palette->{style}->{layer}->schema()->{Properties};
    for my $name (sort keys %$properties) {
        my $property = $properties->{$name};
	next unless $property->{Type};
        my $ok = $palette->valid_property_type($property->{Type});
        next unless $ok;
        push @properties, $name;
        $property_name_is_ok = 1 if defined $property_name && $property_name eq $name;
    }
    undef $property_name unless $property_name_is_ok;
    if (@properties) {
        $property_name = $properties[0] unless $property_name;
        $palette->property($property_name, $properties->{$property_name}->{Type});
    }

    $self->refill_combo('color_property_combobox',
                        \@properties,
                        $property_name);

    my $output_is_hue = $palette->output_is_hue;
    if ($output_is_hue) {
        my @range = $palette->hue_range;
        $self->get_widget('min_hue_label')->set_text($range[0]);
        $self->get_widget('max_hue_label')->set_text($range[1]);
        my $combo = $self->get_widget('hue_range_combobox');
        $combo->set_active($range[2] > 0 ? 0 : 1);
    }

    $palette->set_up_color_view;

    my @color = $palette->{style}->border_color;
    $self->get_widget('border_color_checkbutton')->set_active(@color > 0);
    $self->get_widget('border_color_label')->set_text("@color");

    my %activate;

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

    if ($palette->valid_property_type('Integer')) { # supports properties
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
    
    if (!$palette->valid_property_type('Integer')) { # single color
	for (qw/edit_label edit_color_button/)
        {
            $activate{$_} = 1;
	}
    } elsif ($property_name) {
	for (qw/property_value_label2 property_value_min_entry 
                property_value_label3 property_value_max_entry color_property_value_range_button/) 
        {
            $activate{$_} = 1;
	}
    }

    if ($palette->is_table_like) {
	for (qw/manage_label copy_palette_button open_palette_button save_palette_button 
                edit_label edit_color_button delete_color_button add_color_button/) {
            $activate{$_} = 1;
	}
    }

    if ($palette->{style}->include_border) {
	for (qw/border_color_checkbutton border_color_label border_color_button/) 
        {
            $activate{$_} = 1;
	}
    }

    for my $widget (keys %activate) {
        my $w = $self->get_widget($widget);
        print STDERR "Can't find widget $widget.\n" unless $w;
        next unless $w;
        $w->set_sensitive($activate{$widget});
    }

}

sub color_property_changed {
    my ($combo, $palette) = @_;
    my $self = $palette->{view};
    my $property_name = $palette->{view}->get_value_from_combo('color_property_combobox');
    if (defined $property_name && $property_name ne '') {
        my $properties = $palette->{style}->{layer}->schema()->{Properties};
        $palette->property($property_name, $properties->{$property_name}->{Type});
    } else {
        $palette->property(undef);
    }
    $self->get_widget('property_value_min_entry')->set_text('');
    $self->get_widget('property_value_max_entry')->set_text('');
    $palette->set_up_color_view;
}

sub color_property_value_range_changed {
    my ($entry, $palette) = @_;
    my $self = $palette->{view};
    my $min = POSIX::strtod($self->get_widget('property_value_min_entry')->get_text);
    my $max = POSIX::strtod($self->get_widget('property_value_max_entry')->get_text);
    $palette->value_range($min, $max);
    $palette->update_model;
}

sub hue_changed {
    my ($combo, $palette) = @_;
    my $self = $palette->{view};
    return unless $palette->output_is_hue;
    my $min = POSIX::strtod($self->get_widget('min_hue_label')->get_text);
    my $max = POSIX::strtod($self->get_widget('max_hue_label')->get_text);
    my $dir = $self->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1; # up is 1, down is -1
    $palette->hue_range($min, $max, $dir);
    $palette->update_model;
}

# button callbacks

sub apply_coloring {
    my ($palette, $close) = @{$_[1]};
    my $self = $palette->{view};
    my @color = split(/ /, $palette->{coloring_dialog}->get_widget('border_color_label')->get_text);
    my $has_border = $palette->{coloring_dialog}->get_widget('border_color_checkbutton')->get_active();
    @color = () unless $has_border;
    $palette->border_color(@color);
    $palette->hide_dialog('coloring_dialog') if $close;
    $palette->{style}->{layer}->{glue}->{overlay}->render;
}

sub cancel_coloring {
    my ($button, $palette) = @_;
    my $self = $palette->{view};
    $palette->restore_from($palette->{backup});
    $palette->hide_dialog('coloring_dialog');
    $palette->{style}->{layer}->{glue}->{overlay}->render;
    return 1;
}

sub copy_palette {
    my ($button, $palette) = @_;
    my $self = $palette->{view};
    my $table = copy_palette_dialog($palette);
    if ($table) {
	my $palette = $palette->palette;
	if ($palette eq 'Color table') {
	    $palette->color_table($table);
	} elsif ($palette eq 'Color bins') {
	    $palette->color_bins($table);
	}
	$palette->update_model;
    }
}

sub open_palette {
    my ($button, $palette) = @_;
    my $self = $palette->{view};
    my $filename = file_chooser("Select a $palette file", 'open');
    if ($filename) {
	if ($palette eq 'Color table') {
	    eval {
		$palette->color_table($filename);
	    }
	} elsif ($palette eq 'Color bins') {
	    eval {
		$palette->color_bins($filename);
	    }
	}
	if ($@) {
	    $palette->{glue}->message("$@");
	} else {
            $palette->update_model;
	}
    }
}

sub save_palette {
    my ($button, $palette) = @_;
    my $self = $palette->{view};
    my $palette_type = $palette->palette_type;
    my $filename = file_chooser("Save $palette_type file as", 'save');
    if ($filename) {
	if ($palette_type eq 'Color table') {
	    eval {
		$palette->save_color_table($filename); 
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		$palette->save_color_bins($filename);
	    }
	}
	if ($@) {
	    $palette->{glue}->message("$@");
	}
    }
}

sub edit_color {
    my ($button, $palette) = @_;
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
    my ($button, $palette) = @_;
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
    my ($button, $palette) = @_;
    $palette->add_color($palette->new_property_value, 0, 0, 0, 255);
    $palette->update_model;
}

sub set_hue_range {
    my ($palette, $dir) = @{$_[1]};
    my $self = $palette->{view};
    my $hue = $self->get_widget($dir.'_hue_label')->get_text();
    my @color = hsv2rgb($hue, 1, 1);
    my $color_chooser = Gtk2::ColorSelectionDialog->new("Choose $dir hue for rainbow palette");
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    my $ok = $color_chooser->run eq 'ok';
    if ($ok) {
	$c = $s->get_current_color;
	@color = rgb2hsv($c->red/257, $c->green/257, $c->blue/257);
	$palette->{view}->get_widget($dir.'_hue_label')->set_text(int($color[0]+0.5));
    }
    $color_chooser->destroy;
    hue_changed(undef, $palette) if $ok;
}

sub border_color_dialog {
    my ($button, $palette) = @_;
    my $self = $palette->{view};
    my @color = split(/ /, $self->get_widget('border_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the border lines in '.$palette->name);
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    #$s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257+0.5),int($c->green/257+0.5),int($c->blue/257+0.5));
	#$color[3] = int($s->get_current_alpha()/257);
	$self->get_widget('border_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

sub fill_color_property_value_range {
    my ($button, $palette) = @_;
    my $self = $palette->{view};
    my @range;
    my $property = $palette->property;
    eval {
	@range = $palette->{style}->{layer}->value_range($property);
    };
    if ($@) {
	$palette->{glue}->message("$@");
	return;
    }
    $palette->value_range(@range);
    $self->get_widget('property_value_min_entry')->set_text($range[0]);
    $self->get_widget('property_value_max_entry')->set_text($range[1]);
    $palette->update_model;
}

# color treeview subs

sub copy_palette_dialog {
    my ($palette) = @_;
    my $self = $palette->{view};

    my $palette_type = $palette->palette_type;
    my $dialog = $palette->{glue}->get_dialog('coloring_from_dialog');
    $self->get_widget('coloring_from_dialog')->set_title("Get $palette_type from");
    my $treeview = $self->get_widget('coloring_from_treeview');

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
    for my $layer (@{$palette->{layer}->{glue}->{overlay}->{layers}}) {
	next if $layer->name() eq $palette->name();
	push @names, $layer->name();
	$model->set ($model->append(undef), 0, $layer->name());
    }

    $self->get_widget('coloring_from_dialog')->show_all;
    $self->get_widget('coloring_from_dialog')->present;

    my $response = $palette->{view}->get_widget('coloring_from_dialog')->run;

    my $table;

    if ($response eq 'ok') {

	my @sel = $treeview->get_selection->get_selected_rows;
	if (@sel) {
	    my $i;
            $i = $sel[0]->to_string if @sel;
	    my $from_layer = $palette->{glue}->{overlay}->get_layer_by_name($names[$i]);

	    if ($palette_type eq 'Color table') {
		$table = $from_layer->color_table();
	    } elsif ($palette_type eq 'Color bins') {
		$table = $from_layer->color_bins();
	    }
	}
	
    }

    $self->get_widget('coloring_from_dialog')->destroy;

    return $table;
}

1;
