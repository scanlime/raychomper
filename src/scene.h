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

class HistogramImage;

class Scene
{
public:
    struct Material {
        float diffuse, reflective, transmissive;
        Material(float d, float r, float t) : diffuse(d), reflective(r), transmissive(t) {}
    };

    struct Segment {
        ofVec2f p1, p2;
        ofVec2f normal;
        Material m;
        Segment(const ofVec2f &p1, const ofVec2f &p2, const Material &m) :
            p1(p1), p2(p2), normal((p2 - p1).getPerpendicular()), m(m) {}
    };

    std::vector<Segment> segments;
    ofPoint lightSource;

    void clear() {
        segments.clear();
    }

    void add(const Segment &s) {
        segments.push_back(s);
    }

    void add(const ofVec2f &p1, const ofVec2f &p2, const Material &m) {
        segments.push_back(Segment(p1, p2, m));
    }

    void add(const ofVec2f &p1, const ofVec2f &p2, const ofVec2f &p3, const ofVec2f &p4, const Material &m) {
        segments.push_back(Segment(p1, p2, m));
        segments.push_back(Segment(p2, p3, m));
        segments.push_back(Segment(p3, p4, m));
        segments.push_back(Segment(p4, p1, m));
    }

    void castRays(HistogramImage &hist, unsigned count);

private:
    void randomVector(ofVec2f &v)
    {
        float angle = ofRandom(0, M_PI * 2);
        v.x = cos(angle);
        v.y = sin(angle);
    }

    bool raySegmentIntersect(const ofVec2f &rayOrigin, const ofVec2f &rayDirection, const Segment &seg, float &dist)
    {
        /*
         * Ray equation: [rayOrigin + rayDirection * M], 0 <= M
         * Segment equation: [p1 + (p2-p1) * N], 0 <= N <= 1
         * Returns true with dist=M if we find an intersection.
         *
         *  M = (seg1.x + segD.x * N - rayOrigin.x) / rayDirection.x
         *  M = (seg1.y + segD.y * N - rayOrigin.y) / rayDirection.y
         */

        ofVec2f seg1 = seg.p1;
        ofVec2f segD = seg.p2 - seg1;

        /*
         * First solving for N, to see if there's an intersection at all:
         *
         *  M = (seg1.x + segD.x * N - rayOrigin.x) / rayDirection.x
         *  N = (M * rayDirection.y + rayOrigin.y - seg1.y) / segD.y
         *
         *  N = (((seg1.x + segD.x * N - rayOrigin.x) / rayDirection.x) * rayDirection.y + rayOrigin.y - seg1.y) / segD.y
         */

        float raySlope = rayDirection.y / rayDirection.x;
        float n  = ((seg1.x - rayOrigin.x)*raySlope + (rayOrigin.y - seg1.y)) / (segD.y - segD.x*raySlope);
        if (n < 0 || n > 1)
            return false;

        // Now solve for M, which becomes 'dist' if nonnegative.
        float m = (seg1.x + segD.x * n - rayOrigin.x) / rayDirection.x;
        if (m < 0)
            return false;

        dist = m;
        return true;
    }
};
