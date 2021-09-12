// -*- indent-tabs-mode: nil -*-
/*
 Copyright (C) 2012-2018  Kouhei Sutou <kou@cozmixng.org>

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

function RabbitSlide() {
    this.queryParameters = this.parseQueryParameters();
    this.$viewer = $("#viewer");
    if (this.$viewer.length == 0) {
        return;
    }

    this.bindMoveControls();
    this.bindEmbedBox();
    this.bindPermanentLinkBox();

    this.$viewerHeader  = $("#viewer-header");
    this.$viewerContent = $("#viewer-content");
    this.$viewerFooter  = $("#viewer-footer");
    this.$viewerCurrentPage = $("#viewer-current-page");
    this.isMiniMode = this.$viewerContent.width() < 640;
    this.collectImages();
    this.createPanoramaImages();
    var self = this;
    $(window).on("load", function() {
        self.initializeCurrentPage();
    });
    this.$viewerPageSlider = $("#viewer-page-slider");
    this.$viewerPageSlider.slider({
        min: 1,
        max: this.nPages(),
        value: this.currentPage,
        slide: $.proxy(this.onSlide, this)
    });
    this.$viewerContent.click($.proxy(this.onContentClick, this));
    this.applyStyles();
};

RabbitSlide.prototype = {
    parseQueryParameters: function() {
        var pairs = window.location.search.split(/[?&;]/);
        var parameters = {}
        $.each(pairs, function(i, pair) {
            var splittedPair = pair.split("=", 2);
            var key = splittedPair[0];
            var value = splittedPair[1];
            parameters[key] = value;
        });
        return parameters;
    },

    initializeCurrentPage: function() {
        var page = this.queryParameters["page"];
        if (page) {
            this.currentPage = parseInt(page);
        } else {
            this.currentPage = 1;
        }

        var $pageImage = this.images[this.currentPage - 1];
        if ($pageImage) {
            var offset = this.computeImageOffset(this.currentPage);
            this.$panoramaImages.css("left", offset + "px");
        } else {
            this.currentPage = 1;
        }

        this.updateCurrentPageLabel();
        this.updatePermanentLinkPage();
    },

    nPages: function() {
        return this.images.length;
    },

    collectImages: function() {
        this.images = [];
        var i = 0;
        while (true) {
            var $pageImage;
            if (this.isMiniMode) {
                $pageImage = $("#mini-page-image-" + i);
            } else {
                $pageImage = $("#page-image-" + i);
            }
            if ($pageImage.length == 0) {
                return;
            }
            this.images.push($pageImage);
            i++;
        }
    },

    createPanoramaImages: function() {
        if (this.isMiniMode) {
            this.$panoramaImages = $("#mini-page-images");
        } else {
            this.$panoramaImages = $("#page-images");
        }
        this.$panoramaImages
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

    computeImageOffset: function(n) {
        var $pageImage = this.images[n - 1];
        if ($pageImage) {
            return -$pageImage.width() * (n - 1);
        } else {
            return 0;
        }
    },

    moveTo: function(n) {
        var $pageImage = this.images[n - 1];
        if (!$pageImage) {
            return;
        }

        this.$panoramaImages.clearQueue();
        this.$panoramaImages.animate({
            top: 0,
            left: this.computeImageOffset(n)
        });

        this.currentPage = n;

        this.updateCurrentPageLabel();
        this.updatePermanentLinkPage();
        this.$viewerPageSlider.slider("value", n);

        this.focusSlider();
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

    focusSlider: function() {
        this.$viewerPageSlider.children("a").focus();
    },

    updateCurrentPageLabel: function() {
        this.$viewerCurrentPage.text(this.currentPage);
    },

    applyStyles: function() {
        $("#viewer-move-to-first").addClass("icon-fast-backward");
        $("#viewer-move-to-previous").addClass("icon-step-backward");
        $("#viewer-move-to-next").addClass("icon-step-forward");
        $("#viewer-move-to-last").addClass("icon-fast-forward");
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

    bindEmbedBox: function() {
        var toggleEmbedBox = $.proxy(function(event) {
            $("#embed-box").toggle("scale");
        }, this);
        $("#embed-button").click(toggleEmbedBox);
        $("#embed-box-close").click(toggleEmbedBox);
    },

    updatePermanentLinkURL: function() {
        var permanent_link = $("#permanent-link-base").val();
        if ($("#permanent-link-use-page").prop("checked")) {
            permanent_link += "?page=" + $("#permanent-link-page").val();
        }
        $("#permanent-link").val(permanent_link);
    },

    updatePermanentLinkPage: function() {
        $("#permanent-link-page").val(this.currentPage).change();
    },

    bindPermanentLinkBox: function() {
        var updatePermanentLinkURL = $.proxy(function() {
            this.updatePermanentLinkURL();
        }, this);
        $("#permanent-link-page").keyup(updatePermanentLinkURL);
        $("#permanent-link-page").change(updatePermanentLinkURL);
        $("#permanent-link-use-page").change(updatePermanentLinkURL);

        var togglePermanentLinkBox = $.proxy(function(event) {
            $("#permanent-link-box").toggle("scale");
        }, this);
        $("#permanent-link-button").click(togglePermanentLinkBox);
        $("#permanent-link-box-close").click(togglePermanentLinkBox);
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
        if (draggedPageNumber <= 1) {
            if (ui.originalPosition.left < ui.position.left) {
                this.moveToFirst();
            } else {
                this.moveToNext();
            }
        } else if (draggedPageNumber >= this.nPages()) {
            if (ui.originalPosition.left < ui.position.left) {
                this.moveToPrevious();
            } else {
                this.moveToLast();
            }
        } else if (draggedPageNumber == this.currentPage) {
            if (ui.originalPosition.left < ui.position.left) {
                this.moveToPrevious();
            } else {
                this.moveToNext();
            }
        } else {
            this.moveTo(draggedPageNumber);
        }
    },

    onSlide: function(event, ui) {
        this.moveTo(ui.value);
    }
};
