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

class Segment
    constructor: (@x0, @y0, @x1, @y1, diffuse, reflective, transmissive) ->
        # Cumulative probabilities for each event type
        @d1 = diffuse
        @r2 = @d1 + reflective
        @t3 = @r2 + transmissive

        # Calculate normal vector
        dx = @x1 - @x0
        dy = @y1 - @y0
        len = Math.sqrt(dx*dx + dy*dy)
        @xn = dx / len
        @yn = -dy / len


class RayChomper
    constructor: (canvasId) ->
        @canvas = document.getElementById(canvasId)
        @resize()

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

        # Light source
        @lightX = @width / 2
        @lightY = @height / 2

        # Scene walls
        @segments = [
            new Segment(0, 0, @width-1, 0, 0,0,0),
            new Segment(0, 0, 0, @height-1, 0,0,0),
            new Segment(@width-1, @height-1, @width-1, 0, 0,0,0),
            new Segment(@width-1, @height-1, 0, @height-1, 0,0,0),
        ]

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

        br = 500 / @divisor

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
        segments = @segments
        lightX = @lightX
        lightY = @lightY

        @divisor += numRays
        while numRays--

            ################################################################
            # Start a new ray, at the light source

            t = random() * 6.283185307179586
            rayOriginX = lightX
            rayOriginY = lightY
            rayDirX = sin(t)
            rayDirY = cos(t)
            lastSeg = null

            ################################################################
            # Cast until the ray is absorbed

            loop
                closestDist = 1e38
                closestSeg = null

                raySlope = rayDirY / rayDirX

                for s in segments
                    if s == lastSeg
                        continue

                    ########################################################
                    # Ray to Segment Intersection

                    # Ray equation: [rayOrigin + rayDirection * M], 0 <= M
                    # Segment equation: [p1 + (p2-p1) * N], 0 <= N <= 1
                    # Returns true with dist=M if we find an intersection.
                    #
                    #  M = (seg1.x + segD.x * N - rayOrigin.x) / rayDirection.x
                    #  M = (seg1.y + segD.y * N - rayOrigin.y) / rayDirection.y

                    s1x = s.x0
                    s1y = s.y0
                    sDx = s.x1 - s1x
                    sDy = s.y1 - s1y

                    # First solving for N, to see if there's an intersection at all:
                    #
                    #  M = (seg1.x + segD.x * N - rayOrigin.x) / rayDirection.x
                    #  N = (M * rayDirection.y + rayOrigin.y - seg1.y) / segD.y
                    #
                    #  N = (((seg1.x + segD.x * N - rayOrigin.x) / rayDirection.x) *
                    #     rayDirection.y + rayOrigin.y - seg1.y) / segD.y

                    n = ((s1x - rayOriginX)*raySlope + (rayOriginY - s1y)) / (sDy - sDx*raySlope)
                    if n < 0 or n > 1
                        continue

                    # Now solve for M, the ray/segment distance

                    m = (s1x + sDx * n - rayOriginX) / rayDirX
                    if m < 0
                        continue

                    # It's an intersection! Store it, and keep track of the closest one.
                    if m < closestDist
                        closestDist = m
                        closestSeg = s

                if !closestSeg
                    # Escaped from the scene? This may happen due to math inaccuracies.
                    break

                # Locate the intersection point
                intX = rayOriginX + closestDist * rayDirX
                intY = rayOriginY + closestDist * rayDirY

                ################################################################
                # Draw one ray segment on the histogram, from (x0,y0) to (y0,y1)
                
                x0 = rayOriginX
                y0 = rayOriginY
                x1 = intX
                y1 = intY
                
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

                ################################################################
                # What happens to the ray now?

                r = random()
                rayOriginX = intX
                rayOriginY = intY
                lastSeg = closestSeg
            
                if r < closestSeg.d1
                    # Diffuse reflection. Angle randomized.
                    t = random() * 6.283185307179586
                    rayDirX = sin(t)
                    rayDirY = cos(t)

                else if r < closestSeg.r2
                    # Glossy reflection. Angle reflected.
                    xn = closestSeg.xn
                    yn = closestSeg.yn
                    d = 2 * (xn * rayDirX + yn * rayDirY)
                    rayDirX -= d * xn
                    rayDirY -= d * yn

                else if r >= closestSeg.t3
                    # Absorbed
                    break

        # Suppress result
        null


$(document).ready(() ->
    r = new RayChomper('histogramImage')
    r.segments.push(new Segment(300, 100, 4000, 1800, 1.0, 0, 0))
    r.start()
)