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
    ofEnableSmoothing();
    initScene();

    unsigned w = 600;
    gui = new ofxUICanvas(0, 0, ofGetWidth() - 150, 50);

    brightness = 6;
    gui->addMinimalSlider("Brightness", 1.0, 10.0, brightness, OFX_UI_FONT_MEDIUM);

    showHandles = false;
    gui->addToggle("Show Handles", showHandles);

    addingSegment = false;
    gui->setWidgetPosition(OFX_UI_WIDGET_POSITION_RIGHT);
    gui->addToggle("Add Segments", addingSegment);

    ofAddListener(gui->newGUIEvent, this, &testApp::guiEvent);    
}

void testApp::update()
{
}

void testApp::draw()
{
    long t1 = ofGetSystemTimeMicros();
    long long n = 10000;
    scene.castRays(hist, n);
    long t2 = ofGetSystemTimeMicros();
    printf("Rays/sec: %lld\n", n * 1000000 / (t2-t1));

    hist.render(histPixels, exp(brightness));
    histTexture.loadData(histPixels);
    histTexture.draw(0, 0);

    if (showHandles) {
        for (unsigned i = 0; i < scene.segments.size(); ++i) {
            Scene::Segment &seg = scene.segments[i];
            ofLine(seg.p1.x, seg.p1.y, seg.p2.x, seg.p2.y);
        }
    }
}

void testApp::initScene()
{
    hist.clear();
    scene.clear();

    // Light source in screen center
    scene.lightSource.set(ofGetWidth() / 2, ofGetHeight() / 2);

    Scene::Material absorptive(0, 0, 0);
    ofVec2f topLeft(0, 0);
    ofVec2f bottomRight(ofGetWidth()-1, ofGetHeight()-1);
    ofVec2f topRight(bottomRight.x, 0);
    ofVec2f bottomLeft(0, bottomRight.y);

    // Screen boundary
    scene.add(topLeft, topRight, bottomRight, bottomLeft, absorptive);
    scene.freeze();
}

void testApp::keyPressed(int key)
{
}

void testApp::keyReleased(int key)
{
}

void testApp::mouseMoved(int x, int y)
{
}

void testApp::mouseDragged(int x, int y, int button)
{
    if (addingSecondPoint) {
        scene.segments[scene.segments.size() - 1].setP2(ofVec2f(x, y));
        hist.clear();
    }
}

void testApp::mousePressed(int x, int y, int button)
{
    if (addingSegment) {
        ofVec2f p(x, y);
        Scene::Material m(1,0,0);
        scene.add(p, p, m);
        addingSecondPoint = true;
        hist.clear();
    }
}

void testApp::mouseReleased(int x, int y, int button)
{
    addingSecondPoint = false;
}

void testApp::windowResized(int w, int h)
{
    hist.resize(w, h);
    histTexture.allocate(w, h, GL_LUMINANCE);
    initScene();
}

void testApp::gotMessage(ofMessage msg)
{
}

void testApp::dragEvent(ofDragInfo dragInfo)
{ 
}

void testApp::guiEvent(ofxUIEventArgs &e)
{
    string name = e.widget->getName(); 
    int kind = e.widget->getKind(); 

    if (name == "Brightness") {
        ofxUISlider *slider = (ofxUISlider *) e.widget; 
        brightness = slider->getScaledValue(); 
    }
    
    if (name == "Show Handles") {
        ofxUIToggle *slider = (ofxUIToggle *) e.widget;
        showHandles = slider->getValue();
    }

    if (name == "Add Segments") {
        ofxUIToggle *slider = (ofxUIToggle *) e.widget;
        addingSegment = slider->getValue();
    }
}
