/*
 * This file is part of the RayChomper experimental raytracer. 
 * Copyright (c) 2013 Micah Elizabeth Scott <micah@scanlime.org>
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#include "histogramImage.h"
#include <algorithm>


void HistogramImage::resize(unsigned w, unsigned h)
{
    width = w;
    height = h;

    unsigned nCounts = w * h;
    unsigned nBuckets = (nCounts + 255) >> 8;

    counts.resize(nCounts);
    packetCounts.resize(nBuckets);
    packets.resize(nBuckets << 8);
    clear();
}

void HistogramImage::clear()
{
    denominator = 0;
    counts.assign(counts.size(), 0);
    packetCounts.assign(packetCounts.size(), 0);
}

void HistogramImage::writePackets(unsigned block, unsigned count)
{
    for (unsigned i = block << 8, j = i + count; i != j; ++i) {
        Packet p = packets[i];
        counts[(i & ~0xFF) | p.addr] += 1 + unsigned(p.count);
    }
}

void HistogramImage::render(ofPixels &pix, double scale)
{
    // Flush remaining unwritten packets
    for (unsigned i = 0; i < packetCounts.size(); ++i) {
        unsigned count = packetCounts[i];
        if (count) {
            writePackets(i, packetCounts[i]);
            packetCounts[i] = 0;
        }
    }

    pix.allocate(width, height, 1);
    scale /= denominator;

    // Write pixels to image
    for (unsigned i = 0, j = width * height; i != j; ++i) {
        pix[i] = std::max<int>(0, std::min<int>(255, counts[i] * scale));
    }
}

static double fpart(double x)
{
    return x - int(x);
}

void HistogramImage::line(const ofVec2f &p1, const ofVec2f &p2)
{
    /*
     * Modified version of Xiaolin Wu's antialiased line algorithm:
     * http://en.wikipedia.org/wiki/Xiaolin_Wu%27s_line_algorithm
     */

    double x0 = p1.x;
    double x1 = p2.x;
    double y0 = p1.y;
    double y1 = p2.y;

    unsigned hX, hY;    // X/Y stride for histogram array

    if (std::abs(y1 - y0) > std::abs(x1 - x0)) {
        // Swap X and Y axes
        std::swap(x0, y0);
        std::swap(x1, y1);
        hX = width;
        hY = 1;
    } else {
        hX = 1;
        hY = width;
    }

    if (x0 > x1) {
        std::swap(x0, x1);
        std::swap(y0, y1);
    }

    double dx = x1 - x0;
    double dy = y1 - y0;
    float gradient = dx != 0 ? (dy / dx) : 0;

    /*
     * Modification to Wu's algorithm for brightness compensation:
     * The total brightness of the line should be proportional to its
     * length, but with Wu's algorithm it's proportional to dx.
     * Scale the brightness of each pixel to compensate.
     */
    double br = 128 * sqrtf(dx*dx + dy*dy) / dx;

    // First endpoint
    double xend = round(x0);
    double yend = y0 + gradient * (xend - x0);
    double xgap = br * (1 - fpart(x0 + 0.5));
    unsigned xpxl1 = xend;
    unsigned ypxl1 = yend;
    plotC(hX * xpxl1 + hY * ypxl1, int((1 - fpart(yend)) * xgap));
    plotC(hX * xpxl1 + hY * (ypxl1+1), int(fpart(yend) * xgap));
    float intery = yend + gradient;

    // Second endpoint
    xend = round(x1);
    yend = y1 + gradient * (xend - x1);
    xgap = br * fpart(x1 + 0.5);
    unsigned xpxl2 = xend;
    unsigned ypxl2 = yend;
    plotC(hX * xpxl2 + hY * ypxl2, int((1 - fpart(yend)) * xgap));
    plotC(hX * xpxl2 + hY * (ypxl2+1), int(fpart(yend) * xgap)); 

    // In-between
    for (unsigned x = xpxl1 + 1; x < xpxl2; ++x) {
        unsigned iy = intery;
        double fy = fpart(intery);
        plotC(hX * x + hY * iy, int(br * (1-fy)));
        plotC(hX * x + hY * (iy+1), int(br * fy));
        intery += gradient;
    }
}
