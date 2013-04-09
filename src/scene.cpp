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

#include "scene.h"
#include "histogramImage.h"


void Scene::freeze()
{
    for (unsigned i = 0; i < segments.size(); ++i)
        segments[i].frozen = true;
}

void Scene::castRays(HistogramImage &hist, unsigned count)
{
    while (count--) {
        // Start at the light source
        ofVec2f rayOrigin = lightSource;
        ofVec2f rayDirection;
        Segment *lastSeg = 0;
        randomVector(rayDirection);

        // Cast until the ray is absorbed
        while (1) {

            float closestDist = MAXFLOAT;
            Segment *closestSeg = 0;

            // Find the closest segment
            for (unsigned i = 0; i < segments.size(); ++i) {
                float dist;
                Segment &seg = segments[i];
                if (&seg != lastSeg && raySegmentIntersect(rayOrigin, rayDirection, seg, dist) && dist < closestDist) {
                    closestSeg = &seg;
                    closestDist = dist;
                }
            }

            // Plot the ray until it hits our intersection
            ofVec2f intersection = rayOrigin + closestDist * rayDirection;
            hist.line(rayOrigin, intersection);

            // What happens to the ray now?
            float r = ofRandomuf();
            Material m = closestSeg->m;
            lastSeg = closestSeg;
            rayOrigin = intersection;
            
            if (r < m.d1) {
                // Diffuse reflection. Angle randomized.
                randomVector(rayDirection);

            } else if (r < m.r2) {
                // Glossy reflection. Angle reflected.
                ofVec2f normal = closestSeg->normal;
                rayDirection = rayDirection - (2 * rayDirection.dot(normal)) * normal;

            } else if (r < m.t3) {
                // Transmissive. Angle not changed.

            } else {
                // Absorbed.
                break;
            }
        }

        hist.increment();
    }
}
