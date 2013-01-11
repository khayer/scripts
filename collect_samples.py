import cv
import os
import argparse

class Samples:
    def __init__(self):
        self.current = [0,0,0,0]
        self.samples = None


def on_mouse(event, x, y, flags, samples):
    if event == cv.CV_EVENT_LBUTTONUP:
        if samples.current[0] == 0 and samples.current[1] == 0:
            samples.current[0] = x
            samples.current[1] = y
        else:
            samples.current[2] = x - samples.current[0]
            samples.current[3] = y - samples.current[1]
            samples.saveCurrent()

def saveSamples(frame, filename, samples, output):
    cv.SaveImage(filename, frame)
    line = filename + " " + str(len(samples.samples))
    for sample in samples.samples:
        line += " " + str(sample[0]) + " " + str(sample[1])
        line += " " + str(sample[2]) + " " + str(sample[3])
    print line
    output.write(line)
    output.flush()

def next(capture, name):
    frame = cv.QueryFrame(capture)
    cv.ShowImage(name, frame)
    return frame

def perfect_path(str):
  try:
    open(str)
    return os.path.abspath(str)
  except:
    msg = "%r could not be found!" % str
    raise argparse.ArgumentTypeError(msg)


cv.WaitKey(1)
parser = argparse.ArgumentParser(description="""Analyze your
  zero-maze experiment.""")
parser.add_argument('video', metavar='m4v/mpeg',
  type=perfect_path, help=""" video that you want
  to analyze """)
parser.add_argument('--picture')
parser.add_argument('--sum',
                    help='sum the integers (default: find the max)')

args = parser.parse_args()

capture = cv.CaptureFromFile(args.video)
name = "niner"
samples = Samples()
cv.SetMouseCallback(name, on_mouse, samples)
frame = next(capture, name)
while 1:
    x = cv.WaitKey() & 255;
    if x == 110:
        frame = next(capture, name)
    elif x == 115:
        print samples.current
        if (len(samples.samples) > 0):
            posCnt += 1
            filename = default + str(posCnt) + ".jpg"
            saveSamples(frame, filename, samples, file)
            samples.clear()
            frame = next(capture, name)
    elif x == 49:
        negCnt += 1
        cv.SaveImage(negD + str(negCnt) + ".jpg", frame)
        frame = next(capture, name)