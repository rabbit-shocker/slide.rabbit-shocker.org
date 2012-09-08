// -*- indent-tabs-mode: nil -*-
/*
 Copyright (C) 2012  Kouhei Sutou <kou@cozmixng.org>

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

jQuery(function($) {
    function Slide() {
	this.$viewer = $("#viewer");
	if (this.$viewer.length == 0) {
            return;
	}
	this.$viewerHeader  = $("#viewer-header");
	this.$viewerContent = $("#viewer-content");
	this.$viewerFooter  = $("#viewer-footer");
	this.$viewerCurrentPage = $("#viewer-current-page");
	this.collectImages();
	this.currentPage = 1;
        this.$viewerPageSlider = $("#viewer-page-slider");
        this.$viewerPageSlider.slider({
            min: 1,
            max: this.nPages(),
            value: this.currentPage,
            slide: $.proxy(this.onSlide, this)
        });
        this.moveTo(this.currentPage);
        this.$viewerContent.click($.proxy(this.onContentClick, this));
        this.bindMoveControls();
    };

    Slide.prototype = {
        nPages: function() {
            return this.images.length;
        },

        collectImages: function() {
            this.images = [];
            var i = 0;
            while (true) {
                var $page = $("#page-" + i);
                if ($page.length == 0) {
                    return;
                }
                this.images.push($page);
                $page.hide();
                i++;
            }
        },

        moveTo: function(n) {
            var $image = this.images[n - 1];
            if (!$image) {
                return;
            }

            this.currentPage = n;
            this.$viewerContent.children().hide();
            this.$viewerContent.empty();
            this.$viewerContent.append($image);

            this.$viewerCurrentPage.text(this.currentPage);
            this.$viewerPageSlider.slider("value", n);

            $image.show();
        },

        moveToFirst: function() {
            this.moveTo(1);
        },

        moveToNext: function() {
            this.moveTo(this.currentPage + 1);
        },

        moveToPrevious: function() {
            this.moveTo(this.currentPage - 1);
        },

        moveToLast: function() {
            this.moveTo(this.nPages());
        },

        bindMoveControls: function() {
            $("#viewer-move-to-first").click($.proxy(function(event) {
                console.log("first");
                this.moveToFirst();
            }, this));
            $("#viewer-move-to-previous").click($.proxy(function(event) {
                console.log("previous");
                this.moveToPrevious();
            }, this));
            $("#viewer-move-to-next").click($.proxy(function(event) {
                console.log("next");
                this.moveToNext();
            }, this));
            $("#viewer-move-to-last").click($.proxy(function(event) {
                console.log("last");
                this.moveToLast();
            }, this));
        },

        onContentClick: function(event) {
            if (event.target.x + (event.target.width / 2) < event.clientX) {
                this.moveToNext();
            } else {
                this.moveToPrevious();
            }
        },

        onSlide: function(event, ui) {
            this.moveTo(ui.value);
        }
    };

    new Slide();
});
