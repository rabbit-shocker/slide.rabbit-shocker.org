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
	this.$viewerCurrentPage  = $("#viewer-current-page");
	this.collectImages();
	this.currentPage = 0;
        this.$viewerPageSlider = $("#viewer-page-slider");
        this.$viewerPageSlider.slider({
            min: 0,
            max: this.nPages(),
            value: this.currentPage,
            slide: $.proxy(this.onSlide, this)
        });
        this.moveTo(this.currentPage);
        this.$viewer.click($.proxy(this.onClick, this));
    };

    Slide.prototype = {
        nPages: function() {
            if (this.images.length == 0) {
                return 0;
            } else {
                return this.images.length - 1;
            }
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
                i++;
            }
        },

        moveTo: function(n) {
            if (n < 0) {return;}
            if (n >= this.images.length) {return;}

            var i;
            for (i = 0; i < this.images.length; i++) {
                var $image = this.images[i];
                if (i == n) {
                    this.currentPage = n;
                    this.$viewerContent.empty();
                    this.$viewerContent.append($image);
                    this.$viewerCurrentPage.text(this.currentPage);
                    $image.show();
                } else {
                    $image.hide();
                }
            }
        },

        moveToNext: function() {
            if (this.currentPage >= this.images.length - 1) {
                return;
            }
            this.moveTo(this.currentPage + 1);
        },

        moveToPrevious: function() {
            if (this.currentPage == 0) {
                return;
            }
            this.moveTo(this.currentPage - 1);
        },

        onClick: function(event) {
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
