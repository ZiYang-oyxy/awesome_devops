#!/usr/bin/python

# -*- coding: utf-8 -*-
import time
from sys import version_info

if version_info.major != 2: raise Exception('need python2')

import heapq
import sys
import termios
import thread
import threading
import tty
from optparse import OptionParser

__version__ = '1.0.0'

from time import sleep

KEYEVENT = threading.Event()
INCHAR = ''


def wait_for_input():
    """Get a single character of input, validate"""
    global INCHAR

    acceptable_keys = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0']
    while True:
        key = sys.stdin.read(1)
        if not key in acceptable_keys:
            thread.interrupt_main()
        INCHAR = key
        KEYEVENT.set()


def display_itop(seconds, intr_file, top_line):
    """Main I/O loop"""
    irqs = {}
    loops = 0
    width = 0
    topk = 3

    while True:
        # Grab the new display type at a time when nothing is in flux
        if KEYEVENT.isSet():
            KEYEVENT.clear()
            topk = int(INCHAR)

        with open(intr_file, 'r') as f:
            first_line = f.readline()
            cpu_headers = []
            for name in first_line.split():
                num = name[3:]
                cpu_headers.append(num)

            for line in f.readlines():
                vals = line.split()
                irqnum = vals[0].rstrip(':')
                irq = {}
                irq['name'] = ' '.join(vals[len(cpu_headers) + 1:])
                irq['num'] = irqnum
                irq['cpus'] = [int(x) for x in vals[1:len(cpu_headers) + 1]]
                irq['prev_cpus'] = (irqs[irqnum]['cpus'] if irqnum in irqs else [0] * len(cpu_headers))
                irq['diff_cpus'] = [irq['cpus'][i] - irq['prev_cpus'][i] for i in range(len(irq['cpus']))]
                irq['topk_cpus'] = [i for (i, v) in get_top_k_with_idx(irq['diff_cpus'], topk, True)]

                irq['prev_sum'] = irqs[irqnum]['sum'] if irqnum in irqs else 0
                irq['sum'] = sum(irq['cpus'])
                irq['diff_sum'] = irq['sum'] - irq['prev_sum']

                irqs[irqnum] = irq

        def sort_func(val):
            return val['diff_sum']

        rows = sorted(irqs.values(), key=sort_func, reverse=True)
        for idx, irq in enumerate(rows):
            width = max(width, len(str(irq['diff_sum'])))

        # header
        if loops > 0:
            print("\033[47;30mINTs / " + str(seconds) + " second(s) / top " + str(
                topk) + " cpus / top " + str(top_line) + " ints - " + time.ctime() + "\r\033[0m")
        fmtstr = ('INT# %' + str(width) + 's') % ' INCR'
        fmtstr += (' ')
        for i in range(topk):
            fmtstr += '%10s' % ('TOPCPU#' + str(i))
        fmtstr += ('  ')
        fmtstr += ('NAME')
        if loops > 0:
            print(fmtstr + '\r')

        # data
        limit = top_line
        for idx, irq in enumerate(rows):
            diff = irq['diff_sum']
            if not diff:
                continue
            fmtstr = ('%4s %' + str(width) + 'd') % (irq['num'], diff)
            fmtstr += (' ')

            for t in irq['topk_cpus']:
                fmtstr += ('%4s(%3.2d%%)') % (
                    str(t), float(irq['diff_cpus'][t]) / irq['diff_sum'] * 100 if irq['diff_sum'] != 0 else 0)

            fmtstr += '  ' + irq['name']
            if loops > 0:
                print(fmtstr + '\r')
                limit -= 1
            if limit == 0:
                break

        loops += 1
        for _ in range(0, seconds * 10):
            sleep(.1)


def get_top_k(array, k, top=True):
    """Get Top K in O(len(array)logk)"""
    if k == 0:
        return list()
    if top:
        hp = [x for x in array[:k]]
        heapq.heapify(hp)
        for i in range(k, len(array)):
            if hp[0] < array[i]:
                heapq.heappop(hp)
                heapq.heappush(hp, array[i])
        return [x for x in hp]
    else:
        hp = [-x for x in array[:k]]
        heapq.heapify(hp)
        for i in range(k, len(array)):
            if -hp[0] > array[i]:
                heapq.heappop(hp)
                heapq.heappush(hp, -array[i])
        return [-x for x in hp]


def get_top_k_with_idx(array, k, top=True):
    """Get Top K in O(nlogn)"""
    if k == 0:
        return list()
    if top:
        idx_arr = heapq.nlargest(k, range(len(array)), key=array.__getitem__)
        return [(i, array[i]) for i in idx_arr]
    else:
        idx_arr = heapq.nsmallest(k, range(len(array)), key=array.__getitem__)
        return [(i, array[i]) for i in idx_arr]


def main(args):
    """Parse arguments, call main loop"""
    parser = OptionParser(description=__doc__)
    parser.add_option("-t", "--time", default="1", help="update interval in seconds")
    parser.add_option("-f", "--intr_file", default="/proc/interrupts", help="read a file instead of /proc/interrupts")
    parser.add_option("-k", "--topk", default="5", help="top k interrupts")

    parser.add_option("-d", "--debug", action="store_true", default=False, help="debug mode")
    parser.add_option("-v", "--version", action="store_true", default=False, help="get version")
    options = parser.parse_args(args)[0]

    if options.version:
        print(__version__)
        return 0

    if options.debug:
        display_itop(int(options.time), options.intr_file, int(options.topk))
        return 0

    out = sys.stdin.fileno()
    old_settings = termios.tcgetattr(out)
    tty.setraw(sys.stdin.fileno())

    thread.start_new_thread(wait_for_input, tuple())
    try:
        display_itop(int(options.time), options.intr_file, int(options.topk))
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        termios.tcsetattr(out, termios.TCSADRAIN, old_settings)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
