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

#pragma once
#include <ofMain.h>
#include <stdint.h>
#include <vector>

class HistogramImage
{
public:
    // Change the size of this histogram array.
    void resize(unsigned w, unsigned h);

    // Reset the histogram to zero
    void clear();

    // Plot one point on the histogram, given its array index and a weight.
    void plot(unsigned index, unsigned count)
    {
        unsigned block = index >> 8;
        uint8_t packetCount = packetCounts[block];
        Packet p = { (uint8_t)index, count - 1};

        packets[(block << 8) | packetCount] = p;
        packetCounts[block] = ++packetCount;

        if (!packetCount)
            writePackets(block, 0x100);
    }

    // Plot a point, by X/Y coordinate, with clipping.
    void plot(unsigned x, unsigned y, unsigned count)
    {
        if (x < width && y < height)
            plot(x + y*width, count);
    }

    // Plot an antialiased line segment, with clipping. Endpoints are floating point.
    void line(const ofPoint &p1, const ofPoint &p2);

    void increment()
    {
        denominator++;
    }

    void render(ofPixels &pix, double scale);

private:
    uint32_t width, height;
    uint64_t denominator;

    // Master array of histogram counts
    std::vector<uint64_t> counts;

    // Intermediate result from plotting on the histogram; a small packet
    // that we replay to 'counts' in order later, to reduce memory bandwidth.
    struct Packet {
        uint8_t addr;   // Low 8 bits from counts[] index
        uint8_t count;  // Minus one
    };

    // For each block of 256 packets, how many are in use?
    std::vector<uint8_t> packetCounts;

    // Unsorted packets, prior to plotting in 'counts' array. Each group of 256
    // packets represents a separate sorting bucket.
    std::vector<Packet> packets;

    void writePackets(unsigned block, unsigned count);
};
