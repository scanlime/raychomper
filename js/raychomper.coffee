###
    This file is part of the RayChomper experimental raytracer. 
    Copyright (c) 2013 Micah Elizabeth Scott <micah@scanlime.org>

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.
###


class RayChomper
    constructor: (canvasId) ->
        @scene = []
        @canvas = document.getElementById(canvasId)
        @canvas.addEventListener('resize', @resize)
        @resize()

        # xxx
        @canvas.addEventListener('mousemove', ((e) => @mouseMove(e)))
        @mouseX = 0
        @mouseY = 0

    mouseMove: (e) ->
        if !e
            e = event
        @clear()
        @mouseX = e.pageX - @canvas.offsetLeft
        @mouseY = e.pageY - @canvas.offsetTop

    resize: ->
        # Set up our canvas
        @width = @canvas.clientWidth
        @height = @canvas.clientHeight
        @canvas.width = @width
        @canvas.height = @height
        @ctx = @canvas.getContext('2d')

        # Create an ImageData that we'll use to transfer pixels back to the canvas
        @pixelImage = @ctx.getImageData(0, 0, @width, @height)
        @pixels = new Uint8ClampedArray @pixelImage.data.length

        # Reinitialize the histogram
        @counts = new Uint32Array(@width * @height)
        @clear()

    start: ->
        # Start running; worker threads to simulate, timer loop to draw.
        @doFrame()

    doFrame: ->
        @simulate(1000)
        @draw()
        setTimeout((() => @doFrame()), 0)

    clear: ->
        n = @width * @height
        @divisor = 0
        for i in [0..n] by 1
            @counts[i] = 0

    draw: ->
        # Draw the current simulation results to our Canvas

        br = 100 / @divisor

        n = @width * @height
        pix = @pixels
        c = @counts
        i = 0
        j = 0
        while j != n
            v = c[j++] * br
            pix[i++] = v
            pix[i++] = v
            pix[i++] = v
            pix[i++] = 0xFF

        @pixelImage.data.set(pix)
        @ctx.putImageData(@pixelImage, 0, 0)

    simulate: (numRays) ->
        # Main simulation loop! Performance-critical. Hopefully this whole function
        # gets JIT'ed down to a nice contiguous blob of native code.

        sqrt = Math.sqrt
        random = Math.random
        sin = Math.sin
        cos = Math.cos
        counts = @counts

        @divisor += numRays
        while numRays--

            ################################################################
            # Draw one ray segment on the histogram, from (x0,y0) to (y0,y1)
            #
            # Modified version of Xiaolin Wu's antialiased line algorithm:
            # http://en.wikipedia.org/wiki/Xiaolin_Wu%27s_line_algorithm
            #
            # Modification to Wu's algorithm for brightness compensation:
            # The total brightness of the line should be proportional to its
            # length, but with Wu's algorithm it's proportional to dx.
            # Scale the brightness of each pixel to compensate.
            #
            # This implementation also leaves off the endpoints, for speed and
            # to reduce bright spots caused by overrepresentation of endpoints.

            x0 = 300
            y0 = 300
            t = random() * 6.283185307179586
            x1 = @mouseX + sin(t) * 200
            y1 = @mouseY + cos(t) * 200

            dx = x1 - x0
            dy = y1 - y0
            dx = -dx if dx < 0
            dy = -dy if dy < 0

            if dy > dx
                # Swap X and Y axes
                t = x0
                x0 = y0
                y0 = t
                t = x1
                x1 = y1
                y1 = t
                hX = @width
                hY = 1
            else
                hX = 1
                hY = @width

            if x0 > x1
                t = x0
                x0 = x1
                x1 = t
                t = y0
                y0 = y1
                y1 = t

            dx = x1 - x0
            dy = y1 - y0
            gradient = dy / dx
            br = 128 * sqrt(dx*dx + dy*dy) / dx

            x05 = x0 + 0.5
            xend = x05|0
            yend = y0 + gradient * (xend - x0)
            xpxl1 = (xend|0) + 1
            ypxl1 = yend|0
            intery = yend + gradient
            xpxl2 = (x1 + 0.5)|0

            while xpxl1 < xpxl2
                iy = intery|0
                fy = intery - iy
                i = hX * xpxl1 + hY * iy
                counts[i] += br * (1-fy)
                counts[i + hY] += br * fy
                intery += gradient
                xpxl1++

        # Suppress result
        true


$(document).ready(() ->
    r = new RayChomper('histogramImage')
    r.start()
)
