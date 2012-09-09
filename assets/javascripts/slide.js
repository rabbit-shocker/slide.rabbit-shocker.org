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
	this.createPanoramaImages();
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
                var $pageImage = $("#page-image-" + i);
                if ($pageImage.length == 0) {
                    return;
                }
                this.images.push($pageImage);
                i++;
            }
        },

        createPanoramaImages: function() {
            this.$panoramaImages = $("#page-images")
                .css("position", "relative")
                .css("left", "0px");
            var i;
            for (i = 0; i < this.images.length; i++) {
                var $pageImage = this.images[i];
                this.$panoramaImages.append($pageImage);
            }

            var width = this.$viewerContent.width() * this.images.length;
            this.$panoramaImages.width(width);
            this.$panoramaImages.draggable({
                axis: "x",
                stop: $.proxy(this.onPanoramaImagesStop, this)
            });
            this.$viewerContent.append(this.$panoramaImages);
        },

        moveTo: function(n) {
            var $pageImage = this.images[n - 1];
            if (!$pageImage) {
                return;
            }

            this.$panoramaImages.clearQueue();
            this.$panoramaImages.animate({
                top: 0,
                left: -$pageImage.width() * (n - 1)
            });

            this.currentPage = n;

            this.$viewerCurrentPage.text(this.currentPage);
            this.$viewerPageSlider.slider("value", n);
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
                this.moveToFirst();
            }, this));
            $("#viewer-move-to-previous").click($.proxy(function(event) {
                this.moveToPrevious();
            }, this));
            $("#viewer-move-to-next").click($.proxy(function(event) {
                this.moveToNext();
            }, this));
            $("#viewer-move-to-last").click($.proxy(function(event) {
                this.moveToLast();
            }, this));
        },

        onContentClick: function(event) {
            var halfX = this.$viewerContent.offset().left +
                    (this.$viewerContent.width() / 2);
            if (halfX < event.clientX) {
                this.moveToNext();
            } else {
                this.moveToPrevious();
            }
        },

        onPanoramaImagesStop: function(event, ui) {
            var draggedPageNumber =
                    -ui.position.left / this.$viewerContent.width() + 1;
            draggedPageNumber = Math.round(draggedPageNumber);
            if (draggedPageNumber >= this.nPages()) {
                this.moveToLast();
            } else if (draggedPageNumber <= 0) {
                this.moveToFirst();
            } else {
                this.moveTo(draggedPageNumber);
            }
        },

        onSlide: function(event, ui) {
            this.moveTo(ui.value);
        }
    };

    new Slide();
});
