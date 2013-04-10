###
    Worker thread for the RayChomper experimental raytracer. 
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

@onmessage = (event) ->
    msg = event.data

    width = msg.width
    height = msg.height
    lightX = msg.lightX
    lightY = msg.lightY
    segments = msg.segments
    numRays = msg.numRays
    cookie = msg.cookie

    counts = new Uint32Array(width * height)

    sqrt = Math.sqrt
    random = Math.random
    sin = Math.sin
    cos = Math.cos

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
            # Brightness compensation:
            #   The total brightness of the line should be proportional to its
            #   length, but with Wu's algorithm it's proportional to dx.
            #   We scale the brightness of each pixel to compensate.

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
                hX = width
                hY = 1
            else
                hX = 1
                hY = width

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

            # First endpoint
            x05 = x0 + 0.5
            xend = x05|0
            yend = y0 + gradient * (xend - x0)
            xgap = br * (1 - x05 + xend)
            xpxl1 = xend + 1
            ypxl1 = yend|0
            i = hX * xend + hY * ypxl1
            counts[i] += xgap * (1 - yend + ypxl1)
            counts[i + hY] += xgap * (yend - ypxl1)
            intery = yend + gradient

            # Second endpoint
            x15 = x1 + 0.5
            xpxl2 = x15|0
            yend = y1 + gradient * (xpxl2- x1)
            xgap = br * (x15 - xpxl2)
            ypxl2 = yend|0
            i = hX * xpxl2 + hY * ypxl2
            counts[i] += xgap * (1 - yend + ypxl2)
            counts[i + hY] += xgap * (yend - ypxl2)

            # Inner loop!
            i = hX * xpxl1
            e = hX * xpxl2
            while i < e
                fy = br * (intery - (intery|0))
                j = i + hY * (intery|0)
                counts[j] += br - fy
                counts[j + hY] += fy
                intery += gradient
                i += hX

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

    postMessage { 'cookie': cookie, 'counts': counts, 'numRays': msg.numRays }
