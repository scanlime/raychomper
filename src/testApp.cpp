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

#include "testApp.h"

void testApp::setup()
{
    ofSetWindowTitle("Raychomper");
}

void testApp::update()
{
}

void testApp::draw()
{
    scene.castRays(hist, 2000);
    hist.render(histPixels, 400);
    histTexture.loadData(histPixels);
    histTexture.draw(0, 0);
}

void testApp::updateScene()
{
    hist.clear();
    scene.clear();

    // Light source in screen center
    scene.lightSource.set(ofGetWidth() / 2, ofGetHeight() / 2);

    Scene::Material absorptive(0, 0, 0);
    Scene::Material diffuse(0, 1, 0);

    ofVec2f topLeft(0, 0);
    ofVec2f bottomRight(ofGetWidth()-1, ofGetHeight()-1);
    ofVec2f topRight(bottomRight.x, 0);
    ofVec2f bottomLeft(0, bottomRight.y);

    // Screen boundary
    scene.add(topLeft, topRight, bottomRight, bottomLeft, absorptive);

    // Diffuse line following mouse
    ofVec2f mouse(ofGetMouseX(), ofGetMouseY());
    scene.add(mouse, mouse + ofVec2f(800, 300), diffuse);
}

void testApp::keyPressed(int key)
{
}

void testApp::keyReleased(int key)
{
}

void testApp::mouseMoved(int x, int y)
{
    updateScene();
}

void testApp::mouseDragged(int x, int y, int button)
{
}

void testApp::mousePressed(int x, int y, int button)
{
}

void testApp::mouseReleased(int x, int y, int button)
{
}

void testApp::windowResized(int w, int h)
{
    hist.resize(w, h);
    histTexture.allocate(w, h, GL_LUMINANCE);
    updateScene();
}

void testApp::gotMessage(ofMessage msg)
{
}

void testApp::dragEvent(ofDragInfo dragInfo)
{ 
}
