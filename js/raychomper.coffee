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
    constructor: (x0, y0, x1, y1, diffuse, reflective, transmissive) ->
        @setDiffuse(diffuse)
        @setReflective(reflective)
        @setTransmissive(transmissive)
        @setPoint0(x0, y0)
        @setPoint1(x1, y1)

    setDiffuse: (diffuse) ->
        d1 = diffuse
        @r2 += d1 - @d1
        @t3 += d1 - @d1
        @d1 = d1

    setReflective: (reflective) ->
        r2 = @d1 + reflective
        @t3 += r2 - @r2
        @r2 = r2

    setTransmissive: (transmissive) ->
        @t3 = @r2 + transmissive

    setPoint0: (@x0, @y0) ->
        @calculateNormal()

    setPoint1: (@x1, @y1) ->
        @calculateNormal()

    calculateNormal: ->
        dx = @x1 - @x0
        dy = @y1 - @y0
        len = Math.sqrt(dx*dx + dy*dy)
        @xn = -dy / len
        @yn = dx / len


class Renderer
    # Frontend for running raytracing work on several worker threads, and plotting
    # the results on a Canvas.

    constructor: (canvasId) ->
        @canvas = document.getElementById(canvasId)
        @canvas.addEventListener('resize', (e) => @resize())

        # Hardcoded threadpool size
        @workerURI = 'rayworker.js'

        # Placeholders for real workers, created in @start()
        @workers = ({'_index': i} for i in [0..1])

        # Cookies for keeping track of in-flight changes while rendering
        @workCookie = 1
        @bufferCookie = 0

        @callback = () -> null
        @running = false
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

    stop: ->
        @running = false

    start: ->
        @running = true
        @workCookie++
        for w in @workers
            @initWorker(w)

    workerMessage: (event) ->
        worker = event.target
        msg = event.data
        n = @width * @height
        d = @counts

        # The work unit we just got back was stemped with a cookie indicating
        # which version of our scene it belonged with. If this is older than
        # the buffer's cookie, we must discard the work. If it's the same, we can
        # merge it with the existing buffer. If it's newer, we need to begin a
        # fresh buffer.

        if msg.cookie > @bufferCookie
            @raysCast = 0
            for i in [0..n] by 1
                d[i] = 0
            @bufferCookie = msg.cookie

            # Immediately kill any other threads that are working on a job older than this buffer.
            for w in @workers
                if w._latestCookie and w._latestCookie < @bufferCookie
                    @initWorker(w)

        if msg.cookie == @bufferCookie
            s = new Uint32Array(msg.counts)
            for i in [0..n] by 1
                d[i] += s[i]
            @raysCast += msg.numRays
            @callback()

        @scheduleWork(worker)

    scheduleWork: (worker) ->
        if @workCookie != @bufferCookie
            # Parameters changing; use a minimal batch size
            numRays = 1000
        else
            # Scale batches of work so they get longer after the image has settled
            numRays = 0 | Math.min(199999, Math.max(1000, @raysCast / 2))

        worker._latestCookie = @workCookie
        worker._numRays = numRays

        worker.postMessage({
            'width': @width,
            'height': @height,
            'lightX': @lightX,
            'lightY': @lightY,
            'segments': @segments,
            'numRays': numRays,
            'cookie': @workCookie,
            })

    initWorker: (worker, delay) ->
        # (Re)initialize a worker

        index = worker._index
        worker.terminate() if worker.terminate

        worker = new Worker(@workerURI)
        worker._index = index
        worker._latestCookie = null
        worker._numRays = 0

        @workers[index] = worker
        worker.addEventListener('message', (e) => @workerMessage(e))
        @scheduleWork(worker)

    clear: ->
        # Increment the version cookie on our scene, while we allow
        # older versions to draw anyway. Otherwise, we'll keep preempting
        # ourselves before a single frame is rendered.
        @workCookie++

        @startTime = new Date

        if @running
            # If any threads are running really large batches, reset them now.
            for w in @workers
                if w._numRays >= 10000
                    @initWorker(w)

    elapsedSeconds: ->
        t = new Date()
        return (t.getTime() - @startTime.getTime()) * 1e-3

    raysPerSecond: ->
        return @raysCast / @elapsedSeconds()

    drawLight: (br) ->
        # Draw the current simulation results to our Canvas

        br /= @raysCast
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

    drawSegments: (style, width) ->
        # Draw lines over each segment in our scene

        @ctx.strokeStyle = style
        @ctx.lineWidth = width

        for s in @segments
            @ctx.beginPath()
            @ctx.moveTo(s.x0, s.y0)
            @ctx.lineTo(s.x1, s.y1)
            @ctx.stroke()


class ChomperUI
    constructor: (canvasId) ->
        @renderer = new Renderer(canvasId)
        @renderer.callback = () => @redraw()
        @drawingSegment = false

        $('#histogramImage').mousedown((event) =>
            x = event.clientX - @renderer.canvas.offsetLeft
            y = event.clientY - @renderer.canvas.offsetTop
            @renderer.segments.push(new Segment(x, y, x, y, 0.7, 0.3, 0))
            @renderer.clear()
            @drawingSegment = true
            @redraw
        )

        $('#histogramImage').dblclick((event) =>
            x = event.clientX - @renderer.canvas.offsetLeft
            y = event.clientY - @renderer.canvas.offsetTop
            @renderer.clear()
            @redraw
            @renderer.lightX = x
            @renderer.lightY = y
        )

        $('#histogramImage').mouseup((event) =>
            @drawingSegment = false
        )

        $('#histogramImage').mousemove((event) =>
            x = event.clientX - @renderer.canvas.offsetLeft
            y = event.clientY - @renderer.canvas.offsetTop

            if @drawingSegment
                s = @renderer.segments[@renderer.segments.length - 1]
                s.setPoint1(x, y)
                @renderer.clear()
                @redraw
        )

    redraw: ->
        @renderer.drawLight(1000)

        if @drawingSegment
            @renderer.drawSegments('#0dd', 3)

        $('#raysCast').text(@renderer.raysCast)
        $('#raySpeed').text(@renderer.raysPerSecond()|0)

    start: ->
        @renderer.start()

    stop: () ->
        @renderer.stop()


$(document).ready(() ->
    ui = new ChomperUI 'histogramImage'
    ui.start()
)

$('#slider').slider()
